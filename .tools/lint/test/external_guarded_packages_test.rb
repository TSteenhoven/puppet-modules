# frozen_string_literal: true

require_relative 'test_helper'
require_relative 'installed_gem_support'
require_relative 'guarded_packages_support'

# The packaged rule must behave identically in an independent consumer bundle.
class ExternalGuardedPackagesTest < Minitest::Test
  include LintTestSupport
  include InstalledGemSupport
  include GuardedPackagesSupport

  def test_detection_from_the_installed_gem
    write('manifests/site.pp', pair)
    lint('--only-checks=project_guarded_packages', 'manifests')
    refute @status.success?, @output + @errors
    assert_includes @output, 'ensure_packages(): alpha, beta'
    assert_equal pair, read('manifests/site.pp')
  end

  def test_safe_fix_from_the_installed_gem
    write('manifests/site.pp', pair)
    lint('--fix', '--only-checks=project_guarded_packages', 'manifests')
    assert @status.success?, @output + @errors
    assert_equal merged, read('manifests/site.pp')
    lint('--fix', '--only-checks=project_guarded_packages', 'manifests')
    assert @status.success?, @output + @errors
    assert_empty @output
    assert_equal merged, read('manifests/site.pp')
  end
end
