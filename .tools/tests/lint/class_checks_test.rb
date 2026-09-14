require_relative 'test_helper'

class ClassChecksTest < Minitest::Test
  CHECK = "defined(Class['basic_settings::monitoring'])".freeze

  def findings(code, path: 'example.pp')
    lint = PuppetLint.new
    lint.path = path
    lint.code = code
    lint.run
    refute lint.problems.any? { |problem| problem[:check] == :syntax }, 'Class-check fixtures must parse before their findings are asserted'
    lint.problems.select { |problem| problem[:check] == :project_class_check_reuse }
  end

  def with_module_files(paths)
    consumers = ProjectLint::ClassCheckConsumers
    original = consumers.method(:module_files)
    consumers.define_singleton_method(:module_files) { |_| paths }
    yield
  ensure
    consumers.define_singleton_method(:module_files, original)
  end

  def test_a_single_direct_check_or_a_shared_result_is_valid_in_classes_and_defines
    %w[class define].each do |kind|
      assert_empty findings("#{kind} example { if #{CHECK} { notice('Active') } }")
      assert_empty findings("#{kind} example { $enabled = #{CHECK}; if $enabled { notice('Active') }; notice($enabled) }")
      assert_empty findings("#{kind} example { $active = $ensure == present and #{CHECK}; if $active { notice('Active') } }")
    end
    assert_empty findings('class empty {}')
  end

  def test_single_use_aliases_are_rejected_including_parentheses_and_negation
    [CHECK, "(#{CHECK})", "!(#{CHECK})"].each do |value|
      code = "define example {\n  $enabled = #{value}\n  if $enabled { notice('Active') }\n}"
      problems = findings(code)
      assert_equal [2], problems.map { |problem| problem[:line] }
      assert_includes problems.first[:message], 'used only once'
    end
    assert_includes findings("class example { $unused = #{CHECK} }").first[:message], 'unused'
  end

  def test_repeated_checks_are_found_through_nested_blocks_and_mixed_aliases
    first = "class example {\n  $enabled = #{CHECK}\n"
    code = first + "  if $enabled { [1].each |$item| { if #{CHECK} { notice($item) } } }\n}"
    problems = findings(code)
    assert_equal [3], problems.map { |problem| problem[:line] }
    assert_includes problems.first[:message], 'shared variable'
    # Two one-use caches need one shared result, not two conflicting instructions to inline them.
    code = first + "  $other = #{CHECK}; notice($enabled, $other)\n}"
    assert_equal [3], findings(code).map { |problem| problem[:line] }
  end

  def test_class_names_are_canonicalized_without_grouping_different_queries
    code = "class example { notice(#{CHECK}); notice(defined( Class[\"::Basic_settings::Monitoring\"] )) }"
    assert_equal 1, findings(code).length
    assert_equal 1, findings("define example { notice(defined(Class['nginx'])); notice(defined(Class['nginx'])) }").length
    assert_empty findings("class example { notice(#{CHECK}); notice(defined(Class['nginx'])) }")
    assert_empty findings("class example { $ready = defined(Package['systemd']); notice($ready) }")
    assert_empty findings("class example { notice(defined(Class[$first])); notice(defined(Class[$second])) }")
  end

  def test_classes_defines_and_parameter_defaults_are_separate_scopes
    assert_empty findings("class first { notice(#{CHECK}) }\ndefine second { notice(#{CHECK}) }")
    assert_empty findings("class first (Boolean $enabled = #{CHECK}) { notice(#{CHECK}) }")
    code = "class first { $enabled = #{CHECK}; notice($enabled); class second { notice($enabled) } }"
    assert_equal 1, findings(code).length
  end

  def test_reads_are_real_references_including_interpolation_but_not_shadowed_names
    code = "class example { $enabled = #{CHECK}; notice($enabled)\n"
    assert_empty findings(code + 'notice("State: ${enabled}") }')
    assert_equal 1, findings(code + "notice('enabled') # $enabled\n}").length
    assert_equal 1, findings(code + "[true].each |$enabled| { notice($enabled) } }").length
    assert_equal 1, findings(code + "[true].each |$item| { $enabled = true; notice($enabled) } }").length
    assert_equal 1, findings(code + 'notice($::enabled) }').length
    assert_empty findings(code + '[true].each |$item| { notice($enabled) } }')
    assert_empty findings(code + '[true].each |$enabled| { notice($::example::enabled) } }')
    assert_empty findings(code + 'notice($example::enabled) }')
    local = "define example { [1].each |$item| { $enabled = #{CHECK}; notice($enabled) } }"
    assert_equal 1, findings(local).length
    assert_empty findings(local.sub('notice($enabled)', 'notice($enabled, $enabled)'))
  end

  def test_qualified_consumers_in_other_classes_count_as_reuse
    producer = "class example { $enabled = #{CHECK}; notice($enabled) }"
    assert_empty findings(producer + "\n" + 'class consumer { notice($example::enabled) }')
    Dir.mktmpdir('class-check-consumers-') do |directory|
      path = File.join(directory, 'consumer.pp')
      File.write(path, 'class consumer { notice($example::enabled) }')
      with_module_files([path]) do
        assert_empty findings(producer)
        File.write(path, "class consumer { notice('synthetic') } # $example::enabled\n")
        assert_equal 1, findings(producer).length
      end
      # The unsaved editor buffer replaces the old contents of the linted file.
      File.write(path, producer + "\n" + 'class consumer { notice($example::enabled) }')
      with_module_files([path]) do
        assert_equal 1, findings(producer, path: path).length
      end
    end
  end

  def test_erb_reads_count_but_plain_template_text_and_ruby_comments_do_not
    code = "class example { $enabled = #{CHECK}; notice($enabled); "
    assert_empty findings(code + "notice(inline_template('<%= @enabled %>')) }")
    assert_equal 1, findings(code + "notice(inline_template('@enabled<%# @enabled %>')) }").length
    assert_empty findings("define example { $enabled = #{CHECK}; notice(inline_template('<%= @enabled %><%= @enabled %>')) }")
    assert_equal 1, findings(code + "[true].each |$enabled| { notice(inline_template('<%= @enabled %>')) } }").length
  end

  def test_evaluation_order_is_flagged_for_manual_review_without_hiding_duplicates
    code = "class example { notice(#{CHECK}); include basic_settings::monitoring; notice(#{CHECK}) }"
    assert_includes findings(code).first[:message], 'preserve evaluation order'
  end
end
