# frozen_string_literal: true

require_relative 'test_helper'
require_relative 'parameter_filter_support'

# Resolve each source binding independently and preserve the distinction between values and defaults.
class ParameterFilterSourceTest < Minitest::Test
  include LintTestSupport
  include ParameterFilterSupport

  RULE = :project_parameter_passthrough

  def fixed_source(binding = '$source = 2', predicate: '$item != 2')
    <<~PUPPET
      define example::receiver (Any $value = 2) {}
      #{binding}
      $settings = { 'value' => $source }.filter |$key, $item| { #{predicate} }
      example::receiver { 'synthetic': * => $settings }
    PUPPET
  end

  def test_fixed_values_are_redundant_whether_the_filter_keeps_or_removes_them
    ['$item != 2', '$item == 2', '$item != 0', '$item == 0', '2 == $item'].each do |predicate|
      code = fixed_source(predicate: predicate)
      assert_equal [3], finding_lines(code)
      assert_preserved(code, [:warning], review: true)
    end
  end

  def test_each_key_uses_its_own_source_and_destination
    assert_equal [4], finding_lines(mixed_sources)
    assert_equal([5], findings(mixed_sources).map { |finding| finding[:column] })
    assert_preserved(mixed_sources, [:warning], review: true)
  end

  def mixed_sources
    <<~PUPPET
      define example::receiver (Any $a = 2, Any $b = 3, Any $c = 2) {}
      define example::sender (Any $source_a = 2, Any $source_b = 2, Any $source_c = 3) {
        $settings = {
          'a' => $source_a,
          'b' => $source_b,
          'c' => $source_c,
        }.filter |$key, $item| { $item != 2 }
        example::receiver { $name: * => $settings }
      }
    PUPPET
  end

  def test_local_aliases_resolve_to_their_fixed_value
    code = fixed_source("$original = 2\n$intermediate = ($original)\n$source = $intermediate")
    assert_equal [:warning], finding_kinds(code)
    assert_clean_passes(code.sub('$original = 2', '$original = 3'))
  end

  def test_aliases_of_parameter_defaults_remain_overridable
    code = forwarding.sub('$settings =', '$alias = $source; $settings =').sub("'value' => $source", "'value' => $alias")
    assert_equal [:warning], finding_kinds(code)
    assert_clean_passes(code.sub('$item != 7', '$item == 7'))
    assert_clean_passes(code.sub('$item != 7', '$item != 0'))
  end

  def test_parameter_defaults_can_reference_other_parameters
    code = forwarding.sub('$source = 7', '$base = 7, Any $source = $base')
    assert_equal [:warning], finding_kinds(code)
    assert_clean_passes(code.sub('$base = 7', '$base = 8'))
    assert_clean_passes(code.sub('$item != 7', '$item == 7'))
  end

  def test_literal_hash_values_and_class_source_defaults_are_supported
    assert_equal [:warning], finding_kinds(fixed_source.sub("'value' => $source", "'value' => 2"))
    assert_equal [:warning], finding_kinds(forwarding.sub('define example::sender', 'class example::sender'))
  end

  def test_unknown_or_different_sources_are_not_inferred_from_the_predicate
    ['', '$source = 3', '$source = 2.0', "$source = '2'", "$source = lookup('synthetic')",
     "$source = fail('synthetic source must not execute')", '$source = $unknown',
     '$source = $source', "$source = 2\n$source = 3"].each do |binding|
      assert_clean_passes(fixed_source(binding))
    end
    assert_clean_passes(forwarding.sub('Any $source = 7', 'Any $source'))
  end

  def test_exact_source_values_must_match_even_when_puppet_normalizes_comparisons
    code = fixed_source("$source = 'UPPER'", predicate: "$item != 'upper'")
    assert_clean_passes(code.sub('$value = 2', "$value = 'upper'"))
  end

  def test_sources_from_other_scopes_branches_or_later_assignments_are_unknown
    ['class example::owner { $source = 2 }', 'if $enabled { $source = 2 }'].each do |binding|
      assert_clean_passes(fixed_source(binding))
    end
    assert_clean_passes("#{fixed_source('')}\n$source = 2")
    assert_clean_passes(fixed_source("$source = $later\n$later = 2"))
  end

  def test_lambda_parameters_do_not_resolve_to_outer_values
    code = fixed_source.sub('$settings =', '[3].each |$source| { $settings =')
    assert_clean_passes("#{code}\n}")
  end

  def test_identically_named_sources_in_different_definitions_keep_their_own_defaults
    code = forwarding(default: '2', predicate: '$item != 2')
    other = code.lines.drop(1).join.sub('example::sender', 'example::other').sub('$source = 2', '$source = 3')
    assert_equal [3], finding_lines(code + other)
    assert_equal [7], finding_lines(code.sub('$source = 2', '$source = 3') + other.sub('$source = 3', '$source = 2'))
  end

  def test_each_receiver_is_checked_separately_for_a_shared_hash
    code = fixed_source + "define example::other (Any $value = 3) {}\n" \
                          "example::other { 'synthetic': * => $settings }\n"
    assert_equal [3], finding_lines(code)
    assert_equal [3, 3], finding_lines(code.sub('$value = 3', '$value = 2'))
  end
end
