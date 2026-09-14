# frozen_string_literal: true

require_relative 'monitoring_test_case'

# Verify monitoring decisions behavior through the native linter.
class MonitoringDecisionsTest < MonitoringTestCase
  def test_specific_backend_guards_are_rejected_at_any_nesting_depth
    %w[openitcockpit synthetic_backend].each do |backend|
      ["if #{PACKAGE} == '#{backend}'", "unless #{PACKAGE} != '#{backend}'"].each do |condition|
        code = "#{condition} { if $ready { [1].each |$item| { case $item { default: { #{TARGET} } } } } }"
        assert_equal [1], finding_lines(code), code
        assert_equal([1], finding_lines("#{condition} { notice('Other') } else { #{TARGET} }"))
      end
    end
  end

  def test_aliases_and_nonadjacent_preparation_preserve_the_original_decision_location
    code = alias_decision
    assert_equal([2], finding_lines(code))
    assert_empty findings(code.sub("== 'synthetic_backend'", "!= 'none'"))
    shadowed = fixture(:shadowed)
    assert_empty findings(shadowed)
  end

  def test_only_disabled_state_checks_are_allowed_for_backend_values
    ["#{PACKAGE} != 'none'", "'none' == #{PACKAGE}", "!(#{PACKAGE} == 'none')"].each do |condition|
      assert_empty findings("if $enabled and (#{condition}) { #{TARGET} }"), condition
    end
    ["#{PACKAGE} =~ /synthetic/", "#{PACKAGE} !~ /synthetic/", "#{PACKAGE} in ['synthetic_backend']",
     "'synthetic_backend' == #{PACKAGE}", PACKAGE].each do |condition|
      assert_equal 1, findings("if #{condition} { #{TARGET} }").length, condition
    end
    assert_empty findings("$disabled = 'none'; $engine = #{PACKAGE}; if $engine != $disabled { #{TARGET} }")
  end

  def test_backend_decisions_carried_by_branch_assignments_and_selectors_are_rejected
    code = "if #{PACKAGE} == 'synthetic_backend' { $active = true } else { $active = false }\nif $active { #{TARGET} }"
    assert_equal([1], finding_lines(code))
    target = TARGET.sub("'synthetic':", "'synthetic': ensure => $state,")
    code = "$state = #{PACKAGE} ? { 'synthetic_backend' => present, default => absent }\n#{target}"
    assert_equal([1], finding_lines(code))
    assert_empty findings(code.sub("'synthetic_backend' => present, default => absent",
                                   "'none' => absent, default => present"))
    assert_equal 1, findings("case #{PACKAGE} { 'synthetic_backend': { #{TARGET} } default: {} }").length
    assert_empty findings("case #{PACKAGE} { 'none': {} default: { #{TARGET} } }")
    assert_equal 1, findings("case true { (#{PACKAGE} == 'synthetic_backend'): { #{TARGET} } default: {} }").length
  end

  def test_ordinary_package_logic_and_unrelated_backend_work_remain_valid
    assert_empty findings("class empty {}\ninclude empty")
    assert_empty findings("$package = 'nginx'; if $package == 'nginx' { #{TARGET} }")
    assert_empty findings("if #{PACKAGE} == 'synthetic_backend' { notify { 'unrelated': } }\n#{TARGET}")
    assert_empty findings("$unused = #{PACKAGE} == 'synthetic_backend'\n#{TARGET}")
    assert_empty findings(TARGET.sub("'synthetic':", "'synthetic': package => #{PACKAGE},").to_s)
    assert_destructured_backend
  end

  def test_lambda_shadowing_and_independent_declaration_scopes_do_not_leak
    code = "$engine = #{PACKAGE}\n['nginx'].each |$engine| { if $engine == 'nginx' { #{TARGET} } }"
    assert_empty findings(code)
    code = "$engine = #{PACKAGE}\n[1].each |$item| { $engine = 'nginx'; if $engine == 'nginx' { #{TARGET} } }"
    assert_empty findings(code)
    code = "define first { $chosen = #{PACKAGE} == 'synthetic_backend' }\ndefine second { if $chosen { #{TARGET} } }"
    assert_empty findings(code)
    code = "$engine = #{PACKAGE}\n[1].each |$item| { if $engine == 'synthetic_backend' { #{TARGET} } }"
    assert_equal([2], finding_lines(code))
    assert_empty findings(independent_node_scopes)
  end

  def test_local_wrappers_and_cyclic_wrapper_relationships_are_followed
    code = cyclic_wrappers
    assert_equal([3], finding_lines(code))
    assert_empty findings(code.sub("== 'synthetic_backend'", "!= 'none'"))
    assert_equal 1,
                 findings("if #{PACKAGE} == 'synthetic_backend' { " \
                          "nginx::monitoring_cert { 'instance': config_file => '/tmp/synthetic.conf' } }").length
    assert_class_wrappers
  end

  def test_parameters_forwarded_as_the_backend_are_recognized_without_name_guessing
    code = fixture(:code)
    assert_equal([3], finding_lines(code))
    assert_empty findings(code.sub("== 'synthetic_backend'", "!= 'none'"))
  end

  def test_backend_implementation_may_select_its_own_package_and_findings_are_deduplicated
    code = "define basic_settings::monitoring_custom { if #{PACKAGE} == 'synthetic_backend' { #{TARGET} } }"
    assert_empty findings(code)
    code = "$active = #{PACKAGE} == 'synthetic_backend'\nif $active { #{TARGET} }\n" \
           "if $active { basic_settings::monitoring_custom { 'second': } }"
    assert_equal([1], finding_lines(code))
  end

  def independent_node_scopes
    "node 'first.example.org' { $active = #{PACKAGE} == 'synthetic_backend' }\n" \
      "node 'second.example.org' { if $active { #{TARGET} } }"
  end

  def cyclic_wrappers
    <<~PUPPET
      define first { second { $name: } }
      define second { first { 'cycle': } #{TARGET} }
      if #{PACKAGE} == 'synthetic_backend' { first { 'instance': } }
    PUPPET
  end
end
