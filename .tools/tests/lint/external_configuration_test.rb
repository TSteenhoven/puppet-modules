# frozen_string_literal: true

require_relative 'external_test_case'

# Check isolation from personal and consumer settings while honoring shared configuration.
class ExternalConfigurationTest < ExternalTestCase
  def personal_environment
    write('personal/.puppet-lint.rc', "--invalid-personal-option\n--fix\n")
    write('personal_lookup.rb', File.read(File.join(__dir__, 'fixtures/home_lookup.rb')))
    { 'RUBYOPT' => "-r#{File.join(@project, 'personal_lookup.rb')}",
      'SYNTHETIC_LINT_HOME' => File.join(@project, 'personal') }
  end

  def test_readme_entry_point_checks_only_own_files_and_ignores_personal_configuration
    env = personal_environment
    assert_cli_success(extra_env: env)
    assert_includes @output, '2 own manifests'
    assert_personal_configuration_rejected(env)
    assert_cli_success('modules/profile/manifests/init.pp', extra_env: env, directory: @tooling)
    assert_includes @output, '1 own manifests'
    assert_read_only_scope(env)
    assert_equal fixture(:sample), read('Gemfile')
    refute File.exist?(File.join(@project, 'Gemfile.lock'))
    assert_no_cache
  end

  def assert_personal_configuration_rejected(env)
    original = read('.tools/lint.rb')
    replace_script("'--no-config', ", '')
    assert_cli_failure(extra_env: env)
    assert_includes @output, 'invalid-personal-option'
  ensure
    write('.tools/lint.rb', original)
  end

  def assert_read_only_scope(env)
    code = "$values = [1] + [2]\n"
    write('manifests/site.pp', code)
    assert_cli_failure('manifests/site.pp', extra_env: env)
    assert_includes @output, "#{@project}/manifests/site.pp:1:"
    assert_includes @output, 'project_arrays'
    assert_equal code, read('manifests/site.pp')
  end

  def test_readme_entry_point_uses_the_bundle_path_from_the_ci_environment
    write_shared('.bundle/config', "BUNDLE_PATH: missing-gems\n")
    assert_cli_success(extra_env: { 'BUNDLE_IGNORE_CONFIG' => '1', 'BUNDLE_PATH' => 'vendor/bundle' })
    assert_includes @output, '2 own manifests'
    assert_no_cache
  end

  def test_consumer_configuration_is_required_and_shared_changes_take_effect
    append(@tooling, '.puppet-lint.rc', fixture(:log_format))
    write('manifests/site.pp', "$values = [1] + [2]\n")
    assert_cli_failure('manifests/site.pp')
    assert_includes @output, 'shared:project_arrays:1:'
    append(@project, '.puppet-lint.rc', '--invalid-consumer-option')
    assert_cli_failure
    assert_includes @output + @errors, 'invalid-consumer-option'
    remove(@project, '.puppet-lint.rc')
    assert_cli_failure
    assert_includes @errors, 'Missing project lint file'
  end

  def test_consumer_configuration_works_with_the_standard_cli_and_relative_manifest_paths
    env = { 'BUNDLE_GEMFILE' => File.join(@tooling, 'Gemfile'),
            'BUNDLE_FROZEN' => 'true', 'BUNDLE_VERSION' => 'system' }
    command = %w[bundle exec puppet-lint --no-config --config .puppet-lint.rc manifests/site.pp]
    write('manifests/site.pp', "$values = concat([1], [2])\n")
    assert_project_success(*command, extra_env: env)
    assert_relative_diagnostic(command, env)
    remove(@tooling, '.puppet-lint.rc')
    assert_project_failure(*command, extra_env: env)
    assert_includes @errors, 'Missing shared lint file'
  end

  def assert_relative_diagnostic(command, env)
    write('manifests/site.pp', "$values = [1] + [2]\n")
    assert_project_failure(*command, extra_env: env)
    assert_includes @output, 'manifests/site.pp:1:'
    assert_includes @output, 'project_arrays'
  end
end
