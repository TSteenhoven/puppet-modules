# frozen_string_literal: true

require_relative 'test_helper'
require_relative 'parameter_filter_support'

# Compare the omitted value with defaults without removing meaningful filtering conditions.
class ParameterFilterPredicateTest < Minitest::Test
  include LintTestSupport
  include ParameterFilterSupport

  RULE = :project_parameter_passthrough

  def test_filtering_the_receiving_default_is_reported_for_literal_values
    ['undef', 'false', 'true', '0', '7', '-7', '1.5', '-1.5', "''", "'synthetic'",
     '[]', "['synthetic', 7]", '{}', "{ 'enabled' => false }"].each do |value|
      code = forwarding(default: value, predicate: "$item != #{value}")
      assert_equal [3], finding_lines(code)
      assert_preserved(code, [:warning], review: true)
    end
  end

  def test_parameter_names_need_not_match_but_their_defaults_must_match
    assert_equal [:warning], finding_kinds(forwarding)
    assert_includes findings(forwarding).first[:message], 'source value/default matches the receiving default'
    assert_clean_passes(forwarding.sub('$source = 7', '$source = 8'))
  end

  def test_filtering_a_different_value_has_meaning_even_with_equal_source_and_receiver_defaults
    ['0', 'false', 'undef', "'synthetic'"].each do |value|
      assert_clean_passes(forwarding(predicate: "$item != #{value}"))
    end
    assert_clean_passes(forwarding(default: "'first'", predicate: "$item != 'second'"))
    assert_clean_passes(forwarding(default: 'false', predicate: '$item != undef'))
    assert_clean_passes(forwarding(default: "'UPPER'", predicate: "$item != 'upper'"))
  end

  def test_reversed_operands_parentheses_and_arbitrary_value_parameter_names
    ['$item != (7)', '7 != ($item)', '((($item) != 7))'].each do |predicate|
      assert_equal [:warning], finding_kinds(forwarding(predicate: predicate))
    end
    assert_equal [:warning], finding_kinds(forwarding.gsub('$item', '$candidate'))
  end

  def test_other_predicates_and_side_effects_are_not_discarded
    ["$item != 'x'", '$key != 7', '$item == 7', '$item != 7 and $enabled',
     '$item != 7 or $enabled', '$item', '$item !~ /x/', "notice('synthetic'); $item != 7",
     "$item != lookup('filtered_value')", '$item != $default'].each do |predicate|
      assert_clean_passes(forwarding(predicate: predicate))
    end
  end

  def test_the_predicate_must_use_the_value_parameter_and_have_two_arguments
    assert_clean_passes(forwarding.sub('|$key, $item|', '|$item, $key|'))
    assert_clean_passes(forwarding.sub('|$key, $item|', '|$item|'))
  end

  def test_lambda_types_and_defaults_can_have_their_own_runtime_behavior
    assert_clean_passes(forwarding.sub('|$key, $item|', '|String $key, Integer $item|'))
    assert_clean_passes(forwarding.sub('|$key, $item|', '|$key, $item = 7|'))
  end

  def test_each_filter_in_a_chain_must_only_remove_the_receiving_default
    chain = '.filter |$label, $value| { $value != 7 }'
    code = forwarding.sub('* => $settings', "* => ($settings)#{chain}")
    assert_equal [:warning], finding_kinds(code)
    assert_clean_passes(code.sub('$value != 7', '$value != 0'))
    assert_clean_passes(code.sub('$item != 7', '$item != 0'))
  end

  def test_filter_expressions_do_not_execute_puppet_code_during_analysis
    code = forwarding(default: "fail('synthetic default must not execute')")
    assert_clean_passes(code)
    assert_clean_passes(forwarding(predicate: "$item != fail('synthetic filter must not execute')"))
  end
end
