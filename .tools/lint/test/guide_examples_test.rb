# frozen_string_literal: true

require_relative 'test_helper'

# Verify documented fragments and native corrections through the real lint engine.
class GuideExamplesTest < Minitest::Test
  include LintTestSupport

  EXAMPLE = /<!--[ ]lint-example:[ ]([\w, ]+)[ ](warning|error|ignored|clean)(?:[ ](parameters|keyboard_class))?[ ]-->
             \n```puppet\n(.*?)\n```/mx.freeze

  def test_documented_native_corrections_preserve_values_and_are_idempotent
    assert_native_fix(:double_quoted_strings, "$label = \"Example\"\n", "$label = 'Example'\n")
    before = "notify { 'example':\n  message => 'Example',\n  withpath => false,\n}\n"
    after = before.sub('message =>', 'message  =>')
    assert_native_fix(:arrow_alignment, before, after)
  end

  def assert_native_fix(check, before, after)
    problems, fixed = lint_checks(before, [check], fix: true)
    assert_equal [:fixed], problems.map { |problem| problem[:kind] }.uniq
    assert_equal after, fixed
    [false, true].each do |fix|
      remaining, unchanged = lint_checks(fixed, [check], fix: fix)
      assert_empty remaining
      assert_equal after, unchanged
    end
  end

  def test_native_arrow_fix_refuses_an_invalid_derived_column_without_changing_tokens
    code = "notify { 'example':\n  message => 'Example',\n  withpath => false,\n}\n"
    PuppetLint::Checks.new.load_data('example.pp', code)
    check = PuppetLint.configuration.check_object.fetch(:arrow_alignment).new
    problem = check.run.first.merge(arrow_column: 0)
    2.times do
      assert_raises(PuppetLint::NoFix) { check.fix(problem) }
      assert_equal code, PuppetLint::Data.tokens.map(&:to_manifest).join
    end
  end

  def test_documented_fragment_pairs_match_the_named_native_checks
    examples = documented_examples
    refute_empty examples
    examples.each do |checks, expected, wrapper, code|
      code = wrap_fragment(wrapper, code)
      problems, unchanged = lint_checks("#{code}\n", checks.split(', '))
      assert_equal "#{code}\n", unchanged
      assert_equal expected == 'clean' ? [] : [expected.to_sym], problems.map { |problem| problem[:kind] }.uniq,
                   "#{checks}: #{problems.inspect}\n#{code}"
    end
  end

  def documented_examples
    File.read(File.join(LintTestSupport::ROOT, '.tools/lint/README.md')).scan(EXAMPLE)
  end

  def wrap_fragment(wrapper, code)
    case wrapper
    when 'parameters' then "class example (\n#{code}\n) {}"
    when 'keyboard_class' then "#{code}\nclass example (Boolean $keyboard_enable = true) {}"
    else code
    end
  end
end
