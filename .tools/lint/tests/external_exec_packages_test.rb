# frozen_string_literal: true

require_relative 'test_helper'
require_relative 'installed_gem_support'

# Exercise the bounded analysis through an independently installed consumer gem and modulepath.
class ExternalExecPackagesTest < Minitest::Test
  include LintTestSupport
  include InstalledGemSupport

  def test_installed_check_reuses_parent_packages_and_does_not_guess_a_fix
    relative = 'modules/example/manifests/task.pp'
    write('modules/example/manifests/init.pp', "class example { ensure_packages('diffutils') }")
    write(relative, consumer)
    lint('--only-checks', 'project_exec_packages', relative)
    assert @status.success?, @output + @errors
    write('modules/example/manifests/init.pp', "class example { package { 'diffutils': ensure => absent } }")
    assert_missing_and_unchanged(relative)
  end

  def test_installed_check_compares_parent_branches_without_changing_the_define
    relative = 'modules/example/manifests/task.pp'
    write(relative, consumer)
    write('modules/example/manifests/init.pp', conditional_parent)
    lint('--only-checks', 'project_exec_packages', '--fix', relative)
    assert @status.success?, @output + @errors
    assert_equal consumer, read(relative)
    assert_incomplete_parent(relative)
  end

  def conditional_parent
    <<~PUPPET
      class example {
        case $choice {
          'full': { ensure_packages(['diffutils', 'curl']) }
          default: { package { 'diffutils': ensure => installed } }
        }
      }
    PUPPET
  end

  def assert_incomplete_parent(relative)
    write('modules/example/manifests/init.pp', conditional_parent.sub('ensure => installed', 'ensure => absent'))
    lint('--only-checks', 'project_exec_packages', '--fix', relative)
    refute @status.success?, @output + @errors
    assert_includes @output, '[review]'
    assert_equal consumer, read(relative)
  end

  def consumer
    <<~PUPPET
      define example::task {
        if defined(Class['example']) {
          if $enabled {
            if $active {
              exec { 'compare': command => '/usr/bin/cmp first second', require => Package['diffutils'] }
            }
          }
        } else { fail('Required parent missing') }
      }
    PUPPET
  end

  def assert_missing_and_unchanged(relative)
    [[], ['--fix']].each do |options|
      lint('--only-checks', 'project_exec_packages', *options, relative)
      refute @status.success?, @output + @errors
      assert_includes @output, 'no package installation guarantee'
      assert_equal consumer, read(relative)
    end
  end
end
