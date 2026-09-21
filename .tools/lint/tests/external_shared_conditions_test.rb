# frozen_string_literal: true

require_relative 'test_helper'
require_relative 'installed_gem_support'

# Verify the shared-condition check through an independently installed gem.
class ExternalSharedConditionsTest < Minitest::Test
  include InstalledGemSupport

  def test_installed_check_reports_shared_conditions_without_rewriting_resource_order
    code = "if $enabled { notify { 'first': } }\nif $enabled and $extra { notify { 'second': } }\n"
    write('manifests/site.pp', code)
    lint('--fix', '--only-checks=project_shared_conditions', 'manifests')
    assert_equal 1, @status.exitstatus, @output + @errors
    assert_includes @output, 'project_shared_conditions: warning: [review]'
    assert_equal code, read('manifests/site.pp')
    write('manifests/site.pp', "if $enabled { notify { 'first': } if $extra { notify { 'second': } } }\n")
    lint('--only-checks=project_shared_conditions', 'manifests')
    assert @status.success?, @output + @errors
    assert_empty @output
  end
end
