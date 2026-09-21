# frozen_string_literal: true

require_relative 'test_helper'

# Keep unresolved catalog behavior visible without rejecting a demonstrated dependency path.
class PackageGraphBoundariesTest < Minitest::Test
  include LintTestSupport

  RULE = :project_exec_packages
  COMMAND = "exec { 'example': command => 'curl --version', require => Package['curl'] }"

  def test_unrelated_dynamic_notifications_do_not_invalidate_proven_order
    code = "ensure_packages('curl'); #{COMMAND.sub(' }', ', notify => $notification }')}"
    assert_clean_passes(code)
  end

  def test_package_reference_to_an_uninstantiated_class_does_not_import_its_installation
    code = "class example { ensure_packages('curl') }\n" \
           "exec { 'example': command => 'curl --version', require => Class['example'] }"
    assert_preserved(code, [:warning], review: true)
  end

  def test_other_scopes_and_optional_includes_do_not_guarantee_installation
    assert_includes findings("class separate { ensure_packages('curl') }; #{COMMAND}").first[:message],
                    'no package installation guarantee'
    code = "class separate { ensure_packages('curl') }; if $enabled { include separate }; #{COMMAND}"
    assert_preserved(code, [:warning])
  end

  def test_versioned_packages_are_installed_but_other_providers_and_aliases_need_review
    assert_clean_passes("package { 'curl': ensure => '1.2.3' }; #{COMMAND}")
    ["provider => 'custom'", "name => 'some-other-package'", 'ensure => $ensure'].each do |attribute|
      assert_preserved("package { 'curl': #{attribute} }; #{COMMAND}", [:warning], review: true)
    end
  end

  def test_virtual_resources_and_dynamic_install_options_do_not_prove_installation
    ["@package { 'curl': ensure => installed }", "ensure_packages('curl', $options)"].each do |declaration|
      assert_preserved("#{declaration}; #{COMMAND}", [:warning], review: true)
    end
  end

  def test_realizing_a_virtual_package_keeps_the_installation_review_visible
    code = "@package { 'curl': ensure => installed }; realize(Package['curl']); #{COMMAND}"
    assert_preserved(code, [:warning], review: true)
  end

  def test_parameter_defaults_do_not_become_fixed_package_guarantees
    code = "class example(Array $packages = ['curl']) { ensure_packages($packages); #{COMMAND} }"
    assert_preserved(code, [:warning], review: true)
  end

  def test_defaults_before_the_resource_are_used_and_reversed_arrows_keep_direction
    valid = "Package { ensure => installed }; package { 'curl': }; #{COMMAND}"
    assert_clean_passes(valid)
    code = "package { 'curl': ensure => installed }; exec { 'example': command => 'curl --version' }; " \
           "Exec['example'] <- Package['curl']"
    assert_clean_passes(code)
    assert_includes findings(code.sub('<-', '->')).first[:message], 'no dependency path'
  end

  def test_collectors_overrides_and_resource_creators_request_review
    variants = [
      "ensure_packages('curl'); Package['curl'] { ensure => absent }; #{COMMAND}",
      "ensure_packages('curl'); Package <| title == 'curl' |> { ensure => absent }; #{COMMAND}",
      "create_resources('package', $packages); #{COMMAND}",
      "example::installer { 'tools': }; #{COMMAND}"
    ]
    variants.each { |code| assert_preserved(code, [:warning], review: true) }
  end

  def test_alternative_class_guards_and_inheritance_do_not_prove_parent_installation
    parent = "class example { ensure_packages('curl') }; "
    code = "#{parent}define example::task { if defined(Class['example'], Class['other']) { #{COMMAND} } }"
    assert_preserved(code, [:warning], review: true)
    assert_preserved("#{parent}class child inherits example { #{COMMAND} }", [:warning], review: true)
  end
end
