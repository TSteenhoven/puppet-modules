# frozen_string_literal: true

require_relative 'test_helper'

# Verify reuse suggestions through positive class guards, including external parent manifests.
class ParentClassChecksTest < Minitest::Test
  include LintTestSupport

  RULE = :project_class_check_reuse
  CHECK = "defined(Class['optional'])"
  PARENT = "class owner { $enabled = (#{CHECK}); notice($enabled, $enabled) }"

  def test_positive_guards_find_parent_results_and_do_not_offer_an_autofix
    code = "#{PARENT}\ndefine consumer { if (defined(Class['::Owner']) and $valid) { notice(#{CHECK}) } }"
    problems, unchanged = lint(code, fix: true)
    assert_equal 1, problems.length
    assert_equal 2, problems.first[:line]
    assert_includes problems.first[:message], 'Reuse $owner::enabled'
    assert_includes problems.first[:message], 'evaluation order'
    assert_equal code, unchanged
    assert_clean_passes(code.sub("notice(#{CHECK})", 'notice($owner::enabled)'))
  end

  def test_nested_blocks_and_composite_consumers_use_the_parent_result
    code = "#{PARENT}\ndefine consumer { if defined(Class['owner']) { " \
           "[1].each |$item| { $active = $item > 0 and #{CHECK}; notice($active) } } }"
    assert_equal 1, findings(code).length
    code = "#{PARENT}\ndefine consumer { if defined(Class['owner']) { $local = #{CHECK}; notice($local) } }"
    problems = findings(code)
    assert_equal 1, problems.length
    assert_includes problems.first[:message], '$owner::enabled'
  end

  def test_negative_or_disjunctive_guards_and_other_branches_do_not_prove_availability
    ["!defined(Class['owner'])", "defined(Class['owner']) or $valid", '$ready'].each do |condition|
      assert_empty findings("#{PARENT}\ndefine consumer { if (#{condition}) { notice(#{CHECK}) } }")
    end
    assert_empty findings("#{PARENT}\ndefine consumer { if defined(Class['owner']) {} else { notice(#{CHECK}) } }")
    assert_empty findings("#{PARENT}\ndefine consumer { if defined(Class['owner']) {} notice(#{CHECK}) }")
    assert_empty findings("#{PARENT}\ndefine consumer { if defined(Class['owner']) and #{CHECK} { notice('Active') } }")
  end

  def test_guards_do_not_enable_parameter_defaults
    assert_empty findings("#{PARENT}\ndefine consumer (Boolean $enabled = #{CHECK}) { " \
                          "if defined(Class['owner']) { notice($enabled) } }")
  end

  def test_only_unambiguous_class_scope_results_with_the_same_meaning_are_suggested
    ["!#{CHECK}", "true and #{CHECK}", 'defined(Class[$dynamic])', "defined(Package['optional'])"].each do |value|
      assert_empty findings(consumer(PARENT.sub("(#{CHECK})", value)))
    end
    assert_empty findings(consumer(PARENT.sub('class owner', 'define owner')))
  end

  def test_nested_scopes_and_multiple_assignments_do_not_supply_class_results
    code = "class owner { [1].each |$item| { $enabled = #{CHECK}; notice($enabled, $enabled) } }"
    assert_empty findings(consumer(code))
    assert_empty findings(consumer("class owner { class nested { $enabled = #{CHECK}; notice($enabled, $enabled) } }"))
    code = "class owner { if $valid { $enabled = #{CHECK} } else { $enabled = false }; notice($enabled, $enabled) }"
    assert_empty findings(consumer(code))
  end

  def test_conditionally_supplied_results_require_availability_review
    code = consumer("class owner { if $valid { $enabled = #{CHECK}; notice($enabled, $enabled) } }")
    assert_includes findings(code).first[:message], '[review]'
    assert_includes findings(code).first[:message], 'availability'
  end

  def test_parent_resolution_uses_the_modulepath_and_prefers_the_current_buffer
    previous = ENV.fetch('PROJECT_LINT_MODULEPATH', nil)
    Dir.mktmpdir('parent-class-checks-') do |directory|
      ENV['PROJECT_LINT_MODULEPATH'] = directory
      path = File.join(directory, 'owner/manifests/init.pp')
      FileUtils.mkdir_p(File.dirname(path))
      assert_parent_resolution(path)
    end
  ensure
    ENV['PROJECT_LINT_MODULEPATH'] = previous
  end

  def assert_parent_resolution(path)
    File.write(path, PARENT)
    assert_includes findings(consumer('')).first[:message], '$owner::enabled'
    assert_empty findings(consumer('class owner {}'))
    File.write(path, 'class owner {}')
    assert_empty findings(consumer(''))
    assert_equal 1, findings(consumer(PARENT)).length
  end

  def consumer(parent)
    "#{parent}\ndefine consumer { if defined(Class['owner']) { notice(#{CHECK}) } }"
  end
end
