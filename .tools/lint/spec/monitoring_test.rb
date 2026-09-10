require_relative 'test_helper'

class MonitoringTest < Minitest::Test
  TARGET = "basic_settings::monitoring_custom { 'synthetic': }".freeze
  PACKAGE = '$basic_settings::monitoring::package'.freeze

  def findings(code)
    lint = PuppetLint.new
    lint.path = 'example.pp'
    lint.code = code
    lint.run
    lint.problems.select { |problem| problem[:check] == :project_monitoring_backend }
  end

  def test_specific_backend_guards_are_rejected_at_any_nesting_depth
    %w[openitcockpit synthetic_backend].each do |backend|
      ["if #{PACKAGE} == '#{backend}'", "unless #{PACKAGE} != '#{backend}'"].each do |condition|
        code = "#{condition} { if $ready { [1].each |$item| { case $item { default: { #{TARGET} } } } } }"
        assert_equal [1], findings(code).map { |problem| problem[:line] }, code
        assert_equal [1], findings("#{condition} { notice('Other') } else { #{TARGET} }").map { |problem| problem[:line] }
      end
    end
  end

  def test_aliases_and_nonadjacent_preparation_preserve_the_original_decision_location
    code = <<~PUPPET
      $engine = #{PACKAGE}
      $chosen = $engine == 'synthetic_backend'
      notice('Unrelated preparation')
      $active = $ensure == present and $chosen
      if $active { if $ready { #{TARGET} } }
    PUPPET
    assert_equal [2], findings(code).map { |problem| problem[:line] }
    assert_empty findings(code.sub("== 'synthetic_backend'", "!= 'none'"))
    shadowed = "define example (String $engine) { if $engine == 'nginx' { ['synthetic_backend'].each |$engine| { basic_settings::monitoring_custom { $engine: package => $engine } } } }"
    assert_empty findings(shadowed)
  end

  def test_only_disabled_state_checks_are_allowed_for_backend_values
    ["#{PACKAGE} != 'none'", "'none' == #{PACKAGE}", "!(#{PACKAGE} == 'none')"].each do |condition|
      assert_empty findings("if $enabled and (#{condition}) { #{TARGET} }"), condition
    end
    ["#{PACKAGE} =~ /synthetic/", "#{PACKAGE} !~ /synthetic/", "#{PACKAGE} in ['synthetic_backend']", "'synthetic_backend' == #{PACKAGE}", PACKAGE].each do |condition|
      assert_equal 1, findings("if #{condition} { #{TARGET} }").length, condition
    end
    assert_empty findings("$disabled = 'none'; $engine = #{PACKAGE}; if $engine != $disabled { #{TARGET} }")
  end

  def test_backend_decisions_carried_by_branch_assignments_and_selectors_are_rejected
    code = "if #{PACKAGE} == 'synthetic_backend' { $active = true } else { $active = false }\nif $active { #{TARGET} }"
    assert_equal [1], findings(code).map { |problem| problem[:line] }
    code = "$state = #{PACKAGE} ? { 'synthetic_backend' => present, default => absent }\n#{TARGET.sub("'synthetic':", "'synthetic': ensure => $state,")}"
    assert_equal [1], findings(code).map { |problem| problem[:line] }
    assert_empty findings(code.sub("'synthetic_backend' => present, default => absent", "'none' => absent, default => present"))
    assert_equal 1, findings("case #{PACKAGE} { 'synthetic_backend': { #{TARGET} } default: {} }").length
    assert_empty findings("case #{PACKAGE} { 'none': {} default: { #{TARGET} } }")
    assert_equal 1, findings("case true { (#{PACKAGE} == 'synthetic_backend'): { #{TARGET} } default: {} }").length
  end

  def test_ordinary_package_logic_and_unrelated_backend_work_remain_valid
    assert_empty findings("class empty {}\ninclude empty")
    assert_empty findings("$package = 'nginx'; if $package == 'nginx' { #{TARGET} }")
    assert_empty findings("if #{PACKAGE} == 'synthetic_backend' { notify { 'unrelated': } }\n#{TARGET}")
    assert_empty findings("$unused = #{PACKAGE} == 'synthetic_backend'\n#{TARGET}")
    assert_empty findings("#{TARGET.sub("'synthetic':", "'synthetic': package => #{PACKAGE},")}")
    code = "[$backend, $application] = [#{PACKAGE}, 'nginx']\nif $application == 'nginx' { #{TARGET} }"
    assert_empty findings(code)
    assert_equal 1, findings(code.sub("$application == 'nginx'", "$backend == 'synthetic_backend'")).length
  end

  def test_lambda_shadowing_and_independent_declaration_scopes_do_not_leak
    code = "$engine = #{PACKAGE}\n['nginx'].each |$engine| { if $engine == 'nginx' { #{TARGET} } }"
    assert_empty findings(code)
    code = "$engine = #{PACKAGE}\n[1].each |$item| { $engine = 'nginx'; if $engine == 'nginx' { #{TARGET} } }"
    assert_empty findings(code)
    code = "define first { $chosen = #{PACKAGE} == 'synthetic_backend' }\ndefine second { if $chosen { #{TARGET} } }"
    assert_empty findings(code)
    code = "$engine = #{PACKAGE}\n[1].each |$item| { if $engine == 'synthetic_backend' { #{TARGET} } }"
    assert_equal [2], findings(code).map { |problem| problem[:line] }
    code = "node 'first.example.org' { $active = #{PACKAGE} == 'synthetic_backend' }\nnode 'second.example.org' { if $active { #{TARGET} } }"
    assert_empty findings(code)
  end

  def test_local_wrappers_and_cyclic_wrapper_relationships_are_followed
    code = <<~PUPPET
      define first { second { $name: } }
      define second { first { 'cycle': } #{TARGET} }
      if #{PACKAGE} == 'synthetic_backend' { first { 'instance': } }
    PUPPET
    assert_equal [3], findings(code).map { |problem| problem[:line] }
    assert_empty findings(code.sub("== 'synthetic_backend'", "!= 'none'"))
    assert_equal 1, findings("if #{PACKAGE} == 'synthetic_backend' { nginx::monitoring_cert { 'instance': config_file => '/tmp/synthetic.conf' } }").length
    %w[include contain require].each do |function|
      code = "class example { #{TARGET} }\nif #{PACKAGE} == 'synthetic_backend' { #{function} example }"
      assert_equal [2], findings(code).map { |problem| problem[:line] }
    end
  end

  def test_parameters_forwarded_as_the_backend_are_recognized_without_name_guessing
    code = <<~PUPPET
      define example (String $engine) {
        $alias = $engine
        if $engine == 'synthetic_backend' {
          basic_settings::monitoring_custom { $name: package => $alias }
        }
      }
    PUPPET
    assert_equal [3], findings(code).map { |problem| problem[:line] }
    assert_empty findings(code.sub("== 'synthetic_backend'", "!= 'none'"))
  end

  def test_backend_implementation_may_select_its_own_package_and_findings_are_deduplicated
    code = "define basic_settings::monitoring_custom { if #{PACKAGE} == 'synthetic_backend' { #{TARGET} } }"
    assert_empty findings(code)
    code = "$active = #{PACKAGE} == 'synthetic_backend'\nif $active { #{TARGET} }\nif $active { basic_settings::monitoring_custom { 'second': } }"
    assert_equal [1], findings(code).map { |problem| problem[:line] }
  end
end
