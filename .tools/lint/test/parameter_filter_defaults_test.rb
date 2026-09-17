# frozen_string_literal: true

require_relative 'test_helper'
require_relative 'parameter_filter_support'

# Require known receiving defaults and preserve filters when effective configuration is uncertain.
class ParameterFilterDefaultsTest < Minitest::Test
  include LintTestSupport
  include ParameterFilterSupport

  RULE = :project_parameter_passthrough

  def test_an_unknown_or_different_second_key_does_not_hide_the_first_key
    code = forwarding(entries: "'value' => $source, 'other' => $other")
    assert_equal [:warning], finding_kinds(code)
    code = code.sub('$value = 7', '$value = 7, Any $other = 8')
    code = code.sub('$source = 7', '$source = 7, Any $other = 7')
    assert_equal [:warning], finding_kinds(code)
    assert_equal %i[warning warning], finding_kinds(code.sub('$other = 8', '$other = 7'))
  end

  def test_required_or_dynamic_defaults_do_not_prove_redundancy
    assert_clean_passes(forwarding.sub('Any $value = 7', 'Optional[Integer] $value'))
    ["lookup('default')", '$default', '1 + 6', 'Integer', 'Integer[7]'].each do |default|
      assert_clean_passes(forwarding(default: default))
    end
  end

  def test_known_undef_and_false_are_distinct_from_unknown_defaults
    %w[undef false].each do |default|
      assert_equal [:warning], finding_kinds(forwarding(default: default, predicate: "$item != #{default}"))
      assert_clean_passes(forwarding(default: default, predicate: "$item != lookup('default')"))
    end
  end

  def test_dynamic_hash_keys_and_values_inside_literal_defaults_require_review
    assert_clean_passes(forwarding(entries: '$attribute => $source'))
    assert_clean_passes(forwarding(default: '[$element]', predicate: '$item != [$element]'))
    assert_clean_passes(forwarding(default: "{ 'key' => $element }", predicate: "$item != { 'key' => $element }"))
  end

  def test_builtin_unknown_and_class_receivers_do_not_supply_defined_type_defaults
    assert_clean_passes(forwarding.sub('example::receiver {', 'example::unknown {'))
    assert_clean_passes(forwarding.sub('example::receiver {', 'notify {'))
    code = forwarding.sub('define example::receiver', 'class example::receiver')
    assert_clean_passes(code.sub('example::receiver { $name:', "class { 'example::receiver':"))
  end

  def test_resource_defaults_overrides_and_default_bodies_require_review
    code = forwarding.sub('$settings =', 'Example::Receiver { value => 9 } $settings =')
    assert_clean_passes(code)
    assert_clean_passes("#{forwarding}\nExample::Receiver['synthetic'] { value => 9 }")
    assert_clean_passes(forwarding.sub('example::receiver { $name:',
                                       'example::receiver { default: value => 9; $name:'))
  end

  def test_inherited_caller_defaults_require_review
    code = forwarding.sub('define example::sender (Any $source = 7)',
                          'class example::sender (Any $source = 7) inherits example::parent')
    assert_clean_passes(code)
  end

  def test_filtered_hashes_used_as_configuration_data_remain_valid
    assert_clean_passes(forwarding.sub('* => $settings', 'config => $settings'))
  end
end
