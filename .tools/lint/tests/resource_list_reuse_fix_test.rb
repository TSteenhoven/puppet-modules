# frozen_string_literal: true

require_relative 'test_helper'
require_relative 'resource_list_reuse_support'

# Every safe fix proves exact output, syntax, a clean rescan and idempotence.
class ResourceListReuseFixTest < Minitest::Test
  include LintTestSupport
  include ResourceListReuseSupport

  def test_safe_exact_and_reordered_dependencies
    assert_fix pair, shared_pair, count: 1
    assert_fix pair("['alpha', 'beta', 'gamma']", "'gamma', 'alpha', 'beta'"), shared_pair, count: 1
  end

  def test_all_attributes_and_multiple_resources_are_fixed_together
    code = pair
    %w[before notify subscribe].each do |attribute|
      code = code.sub("\n}", "\n  notify { '#{attribute}': #{attribute} => Package['alpha', 'beta', 'gamma'] }\n}")
    end
    expected = code.sub('  ensure_packages(', "  $required_packages = ['alpha', 'beta', 'gamma']\n\n  ensure_packages(")
                   .sub("ensure_packages(['alpha', 'beta', 'gamma']", 'ensure_packages($required_packages')
                   .gsub("Package['alpha', 'beta', 'gamma']", 'Package[$required_packages]')
    assert_fix code, expected, count: 1
  end

  def test_existing_variable_collision_is_not_overwritten
    code = pair.sub('class example {', 'class example (Array $required_packages = []) {')
    assert_preserved code, [:warning], review: true
    code = pair.sub('  # Install', "  $existing = $example::required_packages\n  # Install")
    assert_preserved code, [:warning], review: true
  end

  def test_comments_suppressions_multiline_and_dynamic_values_prevent_fixing
    inputs = [pair.sub("'beta',", "'beta', # Keep this explanation.\n    "),
              pair.sub("['alpha',", "[\n    'alpha',"),
              pair.sub("'gamma']", "'gamma', $extra]"),
              pair.sub("'gamma']", "'gamma', 'gamma']")]
    inputs.each { |code| assert_preserved code, [:warning], review: true }
    code = pair.sub('  # Order', "  # lint:ignore:project_resource_list_reuse\n  # Order")
    assert_preserved "#{code}# lint:endignore\n", [:warning], review: true
    code = "# lint:ignore:project_resource_list_reuse\n#{pair}# lint:endignore\n"
    assert_preserved code, [:ignored]
  end

  def test_reference_values_and_separate_branches_are_review_only
    code = pair.sub("  notify { 'consumer':\n    require =>", '  $references =').sub(
      "Package['alpha', 'beta', 'gamma'],\n  }", "Package['alpha', 'beta', 'gamma']"
    )
    assert_preserved code, [:warning], review: true
    code = pair.sub('  notify {', "  if $enabled {\n  notify {").sub("\n}", "\n  }\n}")
    assert_preserved code, [:warning], review: true
  end

  def test_installation_result_and_inheritance_prevent_fixing
    assert_preserved pair.sub('ensure_packages(', '$result = ensure_packages('), [:warning], review: true
    assert_preserved pair.sub('class example {', 'class example inherits other {'), [:warning], review: true
  end

  def test_statement_without_comment_gets_a_factual_variable_section
    before = pair.sub("  # Install the shared tools.\n", '')
    after = shared_pair.sub('# Install the shared tools.', '# Share packages between installation and dependencies.')
    assert_fix before, after
  end
end
