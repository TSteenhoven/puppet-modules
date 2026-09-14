# frozen_string_literal: true

require_relative 'test_helper'

# Verify the suppression policy contract with native lint diagnostics.
class SuppressionPolicyTest < Minitest::Test
  include LintTestSupport

  def test_only_approved_suppressions_are_allowed
    assert_empty findings('$x = "lint:ignore:140chars"', 'project_suppressions')
    assert_empty findings("# lint:ignore:140chars\n$x = 'demo'\n# lint:endignore", 'project_suppressions')
    source = "$source = 'puppet:///files/example/app.tar.gz'"
    assert_empty findings("#{source} # lint:ignore:puppet_url_without_modules", 'project_suppressions')
    assert_permitted_combinations(source)
    refute_empty findings("$x = 'demo' # lint:ignore:double_quoted_strings", 'project_suppressions')
    refute_empty findings("$x = 'demo' # lint:ignore:140chars lint:ignore:project_arrays", 'project_suppressions')
    refute_empty findings("#{source} # lint:ignore:puppet_url_without_modules lint:ignore:project_puppet_urls",
                          'project_suppressions')
  end

  def test_puppet_url_ignore_is_local_and_keeps_the_additional_check_active
    source = "$source = 'puppet:///files/example/app.tar.gz'"
    annotated = "#{source} # lint:ignore:puppet_url_without_modules"
    assert_equal(%i[ignored warning], finding_kinds("#{annotated}\n#{source}", 'puppet_url_without_modules'))
    scoped = "# lint:ignore:puppet_url_without_modules\n#{source}\n# lint:endignore\n#{source}"
    assert_equal(%i[ignored warning], finding_kinds(scoped, 'puppet_url_without_modules'))
    assert_empty findings(scoped, 'project_suppressions')
    assert_empty findings(annotated, 'project_puppet_urls')

    assert_invalid_mount_remains_active(annotated.sub('/files/', '/invalid/'))
  end

  def test_line_length_suppression_does_not_hide_adjacent_lines_or_other_checks
    line = "$description = '#{'x' * 141}'"
    assert_equal :warning, findings(line, '140chars').first.fetch(:kind)
    annotated = "#{line} # lint:ignore:140chars\n#{line}"
    assert_equal(%i[ignored warning], finding_kinds(annotated, '140chars'))
    assert_equal :warning, findings('$values = [1] + [2] # lint:ignore:140chars', 'project_arrays').first.fetch(:kind)
    comments = "# lint:ignore:140chars\n# #{'x' * 141}\n# lint:endignore\n" + line
    assert_equal(%i[ignored warning], finding_kinds(comments, '140chars'))
  end

  def test_line_length_control_comments_preserve_documentation_validation
    valid = fixture('suppression_policy/comments_preserve_documentation_validation_valid')
    assert_empty findings(valid, 'project_documentation')
    refute_empty findings(valid.sub('@param label', '@param other'), 'project_documentation')
  end

  def assert_permitted_combinations(source)
    %w[140chars puppet_url_without_modules].permutation.each do |checks|
      controls = checks.map { |check| "lint:ignore:#{check}" }.join(' ')
      assert_empty findings("#{source} # #{controls}", 'project_suppressions')
    end
  end

  def assert_invalid_mount_remains_active(code)
    assert_equal([:ignored], finding_kinds(code, 'puppet_url_without_modules'))
    assert_equal([:warning], finding_kinds(code, 'project_puppet_urls'))
    assert_empty findings(code, 'project_suppressions')
  end
end
