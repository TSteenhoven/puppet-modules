# frozen_string_literal: true

require_relative 'test_helper'

# concat requires an array in its first argument, even when a dependency eventually flattens references.
class ReferenceConcatTest < Minitest::Test
  include LintTestSupport

  RULE = :project_resource_references

  def test_dependency_concat_accepts_an_array_of_package_references_without_an_extra_wrapper
    assert_fix "notify { 'consumer': require => concat([Package['a', 'b']], $other) }\n",
               "notify { 'consumer': require => concat(Package['a', 'b'], $other) }\n"
    before = <<~PUPPET
      class example (Array[String] $packages) {
        notify { 'consumer': require => concat([Package[$packages]], $other) }
      }
    PUPPET
    assert_fix before, before.sub('[Package[$packages]]', 'Package[$packages]')
  end

  def test_scalar_and_unknown_first_arguments_keep_their_array
    ["[Package['a']]", '([Package[$unknown]])', '[Package[$unknown]]'].each do |first|
      assert_clean_passes "notify { 'consumer': require => concat(#{first}, $other) }\n"
    end
  end

  def test_later_scalar_references_can_be_unwrapped
    assert_fix "notify { 'consumer': require => concat($other, [Package['a']]) }\n",
               "notify { 'consumer': require => concat($other, Package['a']) }\n"
  end

  def test_ordinary_concat_values_and_other_functions_preserve_their_shape
    assert_clean_passes "$refs = concat([Package['a', 'b']], $other)\n"
    assert_clean_passes "notify { 'consumer': require => custom([Package['a', 'b']], $other) }\n"
  end

  def test_array_shape_is_preserved_for_other_resource_types
    %w[File Service Example::Item Class].each do |type|
      before = "notify { 'consumer': require => concat([#{type}['a', 'b']], $other) }\n"
      assert_fix before, before.sub("[#{type}['a', 'b']]", "#{type}['a', 'b']")
      assert_clean_passes "notify { 'consumer': require => concat([#{type}['a']], $other) }\n"
    end
  end
end
