# frozen_string_literal: true

require_relative 'test_helper'

# Verify package evidence separately from command recognition through the native check.
class PackageGraphTest < Minitest::Test
  include LintTestSupport

  RULE = :project_exec_packages
  COMMAND = "exec { 'example': command => 'curl --version', require => Package['curl'] }"
  PARENT = "class example { ensure_packages('curl') }\n"
  NESTED_CONSUMER = <<~PUPPET
    define example::%<name>s {
      if defined(Class['example']) {
        if $enabled {
          if $active {
            exec { '%<name>s': command => 'curl --version', require => Package['curl'] }
          }
        }
      } else { fail('Required parent missing') }
    }
  PUPPET

  def test_installation_and_order_are_separate_requirements
    assert_includes findings(COMMAND).fetch(0)[:message], 'does not install'
    installed = "ensure_packages(['curl'])\n"
    assert_clean_passes(installed + COMMAND)
    problem = findings("#{installed}exec { 'example': command => 'curl --version' }").fetch(0)
    assert_includes problem[:message], 'no dependency path'
  end

  def test_existing_package_declarations_supply_installation_but_absent_does_not
    assert_clean_passes("package { 'curl': ensure => installed }\n#{COMMAND}")
    assert_includes findings("package { 'curl': ensure => absent }\n#{COMMAND}").fetch(0)[:message],
                    'no package installation'
  end

  def test_local_assignments_lists_defaults_and_subscribe_are_resolved
    code = <<~PUPPET
      class example { $packages = ['curl', 'jq']
        stdlib::ensure_packages($packages, { 'ensure' => 'present' })
        $dependencies = [Package[$packages]]
        Exec { subscribe => $dependencies }
        $command = '/usr/bin/curl --version'
        exec { 'example': command => $command, refresh => ['/usr/bin/jq', '--version'] }
      }
    PUPPET
    assert_clean_passes(code)
  end

  def test_transitive_metaparameters_and_arrows_supply_order
    variants = [
      "file { '/tmp/example': require => Package['curl'] }\n" \
      "exec { 'example': command => 'curl --version', require => File['/tmp/example'] }",
      "Package['curl'] -> File['/tmp/example'] ~> Exec['example']\n" \
      "file { '/tmp/example': }\nexec { 'example': command => 'curl --version' }",
      "package { 'curl': ensure => installed } -> exec { 'example': command => 'curl --version' }"
    ]
    variants.each_with_index do |variant, index|
      assert_clean_passes(index == 2 ? variant : "ensure_packages('curl')\n#{variant}")
    end
  end

  def test_same_module_and_required_parent_installations_are_reused
    dependent = <<~PUPPET
      define example::download {
        if defined(Class['example']) {
          exec { 'download': command => 'curl --version', require => Package['curl'] }
        } else { fail('Required parent missing') }
      }
    PUPPET
    assert_clean_passes(PARENT + dependent)
  end

  def test_required_classes_supply_order_but_include_and_uninstantiated_classes_do_not
    assert_clean_passes("#{PARENT}class child { require example; exec { 'child': command => 'curl --version' } }")
    command = "exec { 'child': command => 'curl --version', require => Class['example'] }"
    assert_clean_passes("#{PARENT}class child { include example; #{command} }")
    included = "#{PARENT}class child { include example; exec { 'child': command => 'curl --version' } }"
    assert_includes findings(included).fetch(0)[:message], 'no dependency path'
    unused = "#{PARENT}class child { exec { 'child': command => 'curl --version' } }"
    assert_includes findings(unused).fetch(0)[:message], 'no package installation'
  end

  def test_nested_consumers_reuse_parent_packages_but_keep_their_own_ordering
    consumers = %w[first second].map { |name| format(NESTED_CONSUMER, name: name) }.join
    assert_clean_passes(PARENT + consumers)
    unordered = consumers.sub(", require => Package['curl']", '')
    problems = findings(PARENT + unordered)
    assert_equal 1, problems.length
    assert_includes problems.first[:message], 'no dependency path'
  end

  def test_unknown_conditions_providers_and_relations_request_specific_review
    variants = [
      "if $enabled { ensure_packages('curl') }; #{COMMAND}",
      "ensure_packages($packages); #{COMMAND}",
      "package { 'curl': ensure => $state }; #{COMMAND}",
      "package { 'curl': provider => $provider }; #{COMMAND}",
      "include unknown; exec { 'example': command => 'curl --version', require => Class['unknown'] }",
      "ensure_packages('curl'); exec { 'example': command => 'curl --version', require => $dependencies }"
    ]
    variants.each { |code| assert_preserved(code, [:warning], review: true) }
  end

  def test_installation_on_the_same_branch_is_valid_but_the_opposite_branch_is_not_proof
    valid = "if $enabled { ensure_packages('curl'); #{COMMAND} }"
    assert_clean_passes(valid)
    assert_preserved("if $enabled { ensure_packages('curl') } else { exec { 'example': command => 'curl --version', " \
                     "require => Package['curl'] } }", [:warning])
  end
end
