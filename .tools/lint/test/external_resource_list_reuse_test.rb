# frozen_string_literal: true

require_relative 'test_helper'
require_relative 'installed_gem_support'
require_relative 'resource_list_reuse_support'

# An independent project receives the active rule and its fix through the packaged entrypoint.
class ExternalResourceListReuseTest < Minitest::Test
  include LintTestSupport
  include InstalledGemSupport
  include ResourceListReuseSupport

  def test_installed_profile_detection_fix_and_idempotence
    relative = 'modules/example/manifests/init.pp'
    write(relative, documented_pair)
    lint(relative)
    refute @status.success?, @output + @errors
    assert_includes @output, 'project_resource_list_reuse'
    assert_equal documented_pair, read(relative)
    assert_consumer_fix(relative)
  end

  def test_installed_profile_keeps_package_names_and_resource_references_separate
    relative = 'modules/example/manifests/init.pp'
    write(relative, fixture('resource_dependencies/before'))
    lint(relative)
    refute @status.success?, @output + @errors
    assert_includes @output, 'project_resource_dependencies'
    assert_consumer_fix(relative, fixture('resource_dependencies/after'))
  end

  def assert_consumer_fix(relative, expected = documented_pair(shared_pair))
    lint('--fix', relative)
    assert @status.success?, @output + @errors
    assert_equal expected, read(relative)
    [[], ['--fix']].each do |options|
      lint(*options, relative)
      assert @status.success?, @output + @errors
      assert_empty @output
      assert_equal expected, read(relative)
    end
  end
end
