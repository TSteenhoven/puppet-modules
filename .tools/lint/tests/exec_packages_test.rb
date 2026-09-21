# frozen_string_literal: true

require_relative 'test_helper'

# Prove only the documented source-level package and relationship contracts.
class ExecPackagesTest < Minitest::Test
  include LintTestSupport

  RULE = :project_exec_packages

  def test_all_command_fields_and_the_implicit_title_are_inspected
    %w[command onlyif unless refresh].each do |field|
      code = "exec { 'example': #{field} => '/usr/bin/cmp first second' }"
      problem = findings(code).fetch(0)
      assert_includes problem[:message], "Exec #{field} uses cmp (diffutils)"
      refute_includes problem[:message], '[review]'
    end
    assert_equal 1, findings("exec { '/usr/bin/cmp first second': } ").length
    assert_empty findings("exec { '/usr/bin/cmp first second': command => 'true' }")
  end

  def test_command_arrays_and_multiple_string_or_array_guards
    code = <<~PUPPET
      exec { 'example':
        command => ['/usr/bin/curl', 'https://example.org/'],
        onlyif => ['cmp a b', ['/usr/bin/jq', '.', '/tmp/data']],
        unless => [['/usr/bin/wget', '--version']],
        refresh => ['/bin/bash', '-c', 'true'],
      }
    PUPPET
    assert_equal 5, findings(code).length
    assert_empty findings("exec { 'example': command => ['printf', 'curl'] }")
  end

  def test_builtins_functions_presence_tests_optional_tools_and_agent_are_not_package_demands
    commands = ['true', 'printf curl', 'test -x /usr/bin/curl', '[ -x /usr/bin/curl ]', 'command -v curl',
                '/usr/bin/test -x /usr/bin/curl', 'puppet --version', '/opt/puppetlabs/bin/puppet --version',
                'local_helper', 'curl() { printf ready; }; curl', 'curl --version || printf unavailable']
    commands.each { |command| assert_clean_passes("exec { 'example': command => '#{command}' }") }
    ['test -x /usr/bin/curl', '[ -x /usr/bin/curl ]', 'command -v curl >/dev/null 2>&1'].each do |guard|
      assert_clean_passes("exec { 'example': command => 'curl --version', onlyif => '#{guard}' }")
    end
    assert_empty findings("exec { 'install': command => '/usr/local/bin/install-curl', unless => 'command -v curl' }")
  end

  def test_dynamic_arguments_do_not_hide_a_fixed_executable_or_expose_argument_values
    code = 'exec { "example": command => "/usr/bin/curl ${escaped}", require => Package["curl"] }'
    problem = findings(code).fetch(0)
    assert_includes problem[:message], 'curl'
    refute_includes problem[:message], 'escaped'
    assert_empty findings('exec { "example": command => "/usr/bin/cu${suffix}" }')
  end

  def test_unknown_executables_and_complex_shell_bodies_remain_manual_review
    %w[/usr/local/bin/helper /bin/sh].each do |command|
      assert_clean_passes("exec { 'example': command => '#{command}' }")
    end
    assert_empty findings('exec { "example": command => $command }')
  end

  def test_presence_tests_as_guard_argument_arrays_keep_tools_optional
    code = "exec { 'example': command => ['/usr/bin/curl', '--version'], " \
           "onlyif => [['/usr/bin/test', '-x', '/usr/bin/curl']] }"
    assert_clean_passes(code)
  end
end
