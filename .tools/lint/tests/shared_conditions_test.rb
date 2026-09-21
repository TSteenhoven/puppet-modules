# frozen_string_literal: true

require_relative 'test_helper'

# Verify shared-condition diagnostics across resource kinds and lexical scopes.
class SharedConditionsTest < Minitest::Test
  include LintTestSupport

  RULE = :project_shared_conditions

  def test_compound_condition_reuses_the_existing_guard_across_intervening_resources
    code = <<~PUPPET
      if ($ensure == present) { file { '/tmp/config': } } else { $content = undef }
      notify { 'independent': }
      if ($ensure == present and $monitoring) { profile::check { 'example': } }
    PUPPET
    problems = findings(code)
    assert_equal([[3, 1, :warning]], problems.map { |problem| problem.values_at(:line, :column, :kind) })
    assert_includes problems.first[:message], 'existing condition at line 1'
    assert_preserved(code, [:warning], review: true)
  end

  def test_existing_guard_can_follow_the_more_specific_condition
    code = "if $enabled and $extra { realize(File['example']) }\nif $enabled { file { '/tmp/config': } }\n"
    problems = findings(code)
    assert_equal([1], problems.map { |problem| problem[:line] })
    assert_includes problems.first[:message], 'existing condition at line 2'
  end

  def test_repeated_guards_report_each_additional_branch_once
    code = (1..3).map { |number| "if $enabled { notify { 'example#{number}': } }\n" }.join
    assert_equal [2, 3], finding_lines(code)
  end

  def test_parentheses_and_literal_quoting_do_not_hide_the_same_condition
    code = "if (($ensure) == 'present') { file { '/tmp/config': } }\n" \
           "if (($ensure == present) and $monitoring) { profile::check { 'example': } }\n"
    assert_equal [2], finding_lines(code)
    ['$enabled', '!$disabled', '!($ensure == present)'].each do |condition|
      assert_equal [2], finding_lines("if (#{condition}) { include first }\nif (#{condition}) { contain second }\n")
    end
  end

  def test_other_conditions_and_literal_types_remain_distinct
    ['$ensure == absent', '$other == present', '$ensure != present', '$ensure == true',
     '$ensure == 1'].each do |condition|
      assert_clean_passes("if $ensure == present { notify { 'first': } } if #{condition} { notify { 'second': } }")
    end
    assert_clean_passes("if $value == '1' { notify { 'first': } } if $value == 1 { notify { 'second': } }")
  end

  def test_grouped_resources_with_individual_conditions_are_clean
    assert_clean_passes(<<~PUPPET)
      if $ensure == present {
        file { '/tmp/config': }
        if $monitoring { profile::check { 'example': } }
      } else {
        file { '/tmp/config': ensure => absent }
      }
    PUPPET
  end

  def test_separate_blocks_declarations_and_lambda_scopes_are_not_combined
    first = "if $enabled { notify { 'first': } }"
    second = "if $enabled { notify { 'second': } }"
    ["class first { #{first} } class second { #{second} }",
     "if $outer { #{first} } else { #{second} }",
     "#{first} ['item'].each |$enabled| { #{second} }",
     "#{first} if $outer { #{second} }"].each { |code| assert_clean_passes(code) }
  end

  def test_disjunctions_dynamic_calls_and_unless_do_not_establish_a_shared_guard
    ["defined(File['example'])", '$enabled or $extra', 'example::enabled()'].each do |condition|
      assert_clean_passes("if #{condition} { notify { 'first': } } if #{condition} { notify { 'second': } }")
    end
    assert_clean_passes("unless $enabled { notify { 'first': } } if $enabled { notify { 'second': } }")
  end

  def test_only_an_existing_complete_guard_can_own_a_compound_branch
    assert_clean_passes("if $enabled and $one { notify { 'first': } } if $enabled and $two { notify { 'second': } }")
    assert_clean_passes("if $enabled { notify { 'first': } } if $extra and $enabled { notify { 'second': } }")
  end

  def test_assignments_strings_and_comments_are_not_resource_work
    prefix = "if $enabled { notify { 'first': } }\n"
    ['if $enabled { $value = 1 }', "# if $enabled { notify { 'comment': } }",
     "$text = 'if $enabled { notify {} }'",
     "$value = if $enabled { 'one' } else { 'two' }"].each do |suffix|
      assert_clean_passes(prefix + suffix)
    end
  end

  def test_resource_overrides_defaults_and_resources_in_iterations_share_the_guard
    ["File['/tmp/config'] { mode => '0600' }", "File { mode => '0600' }",
     "['item'].each |$item| { notify { $item: } }", "ensure_packages(['example'])"].each do |body|
      assert_equal [:warning], finding_kinds("if $enabled { file { '/tmp/config': } } if $enabled { #{body} }")
    end
  end

  def test_native_suppression_is_respected_and_diagnostics_do_not_include_source_values
    code = "if $value == 'synthetic-private-value' { notify { 'first': } }\n" \
           "if $value == 'synthetic-private-value' { notify { 'second': } }\n"
    refute_includes findings(code).first[:message], 'synthetic-private-value'
    assert_preserved("# lint:ignore:project_shared_conditions\n#{code}# lint:endignore\n", [:ignored])
  end
end
