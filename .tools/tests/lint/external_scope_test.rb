# frozen_string_literal: true

require_relative 'external_test_case'

# Preserve downstream failure behavior for invalid input, missing tooling and source scope.
class ExternalScopeTest < ExternalTestCase
  def test_missing_plugins_syntax_errors_and_empty_or_wrong_scope_fail
    write('manifests/site.pp', 'class broken (String $value = ) {}')
    assert_cli_failure
    assert_includes @output, 'Invalid Puppet syntax'
    remove(@tooling, '.tools/lint/lib/puppet-lint/plugins/resources.rb')
    assert_cli_failure
    assert_includes @errors, 'resources.rb'
    assert_cli_failure('spec/fixtures/invalid.pp')
    assert_includes @errors, 'outside the own lint scope'
    assert_missing_sources
  end

  def assert_missing_sources
    %w[manifests/site.pp modules/profile/manifests/init.pp].each { |path| remove(@project, path) }
    assert_cli_failure
    assert_includes @errors, 'No own Puppet manifests selected'
    FileUtils.rmdir(File.join(@project, 'manifests'))
    assert_cli_failure
    assert_includes @errors, 'Missing source directory'
  end

  def test_readme_entry_point_requires_a_files_ignore_and_keeps_mount_validation_active
    [
      ['modules', false, nil], ['files', false, 'puppet_url_without_modules'],
      ['files', true, nil], ['invalid', true, 'project_puppet_urls']
    ].each { |mount, ignore, check| assert_mount(mount, ignore, check) }
  end

  def assert_mount(mount, ignore, expected_check)
    write('manifests/site.pp', mount_source(mount, ignore))
    capture_cli
    assert_includes @output, '2 own manifests'
    if expected_check
      refute @status.success?, @output + @errors
      assert_equal [expected_check], @output.scan(/^.+:6:13: (\w+): warning:/).flatten, @output + @errors
    else
      assert @status.success?, @output + @errors
    end
    refute_includes @output, 'project_suppressions'
  end

  def mount_source(mount, ignore)
    control = ignore ? ' # lint:ignore:puppet_url_without_modules' : ''
    <<~PUPPET
      file { '/tmp/synthetic-app.tar.gz':
        ensure => file,
        owner  => 'root',
        group  => 'root',
        mode   => '0600',
        source => 'puppet:///#{mount}/example/app.tar.gz',#{control}
      }
    PUPPET
  end
end
