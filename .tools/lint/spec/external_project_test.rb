require_relative 'test_helper'
require 'bundler'
require 'fileutils'

class ExternalProjectTest < Minitest::Test
  def setup
    @project = Dir.mktmpdir('external-lint-')
    @tooling = File.join(@project, 'dependencies/shared modules/puppet-modules')
    FileUtils.mkdir_p(File.join(@tooling, '.tools/lint'))
    FileUtils.cp_r(File.join(ProjectLint::ROOT, '.tools/lint/lib'), File.join(@tooling, '.tools/lint'))
    %w[.puppet-lint.rc Gemfile Gemfile.lock].each do |name|
      FileUtils.cp(File.join(ProjectLint::ROOT, name), @tooling)
    end

    # Run the actual README entry point, changing only the documented dependency location.
    readme = File.read(File.join(ProjectLint::ROOT, '.tools/lint/README.md'))
    script = readme[/^```ruby\n(.*?)^```/m, 1]
    refute_nil script
    write('.tools/lint.rb', script.sub("'global-modules'", "'dependencies/shared modules/puppet-modules'"))
    config = readme[/^```text\n(--load=.*?)^```/m, 1]
    refute_nil config
    write('.puppet-lint.rc', config.sub('global-modules/', 'dependencies/shared modules/puppet-modules/'))
    write('modules/profile/manifests/init.pp', <<~'PUPPET')
      # @summary Provides a synthetic local interface.
      # @param value A synthetic input.
      # @example Declare the local profile
      #   class { 'profile': value => 'synthetic' }
      # @api public
      class profile (
        String $value,
      ) {
      }
    PUPPET
    FileUtils.mkdir_p(File.join(@tooling, 'shared/manifests'))
    File.write(File.join(@tooling, 'shared/manifests/init.pp'), 'class shared (String $value) {}')
    write('manifests/site.pp', <<~'PUPPET')
      $values = concat([1], [2])
      class { 'profile':
        value => 'synthetic',
      }
      class { 'shared':
        value => 'synthetic',
      }
    PUPPET
    %w[spec/fixtures/invalid.pp modules/vendor/manifests/init.pp vendor/bundle/invalid.pp].each do |path|
      write(path, "$values = [1] + [2]\n")
    end
    write('Gemfile', "raise 'The consumer bundle must not be loaded'\n")

    # Reuse installed, locked gems without network access or modifying the developer's bundle.
    FileUtils.mkdir_p(File.join(@tooling, '.bundle'))
    File.write(File.join(@tooling, '.bundle/config'), "BUNDLE_PATH: vendor/bundle\n")
    gem_home = File.join(@tooling, 'vendor/bundle', 'ruby', RbConfig::CONFIG.fetch('ruby_version'))
    Bundler.load.specs.each do |spec|
      next if spec.name == 'bundler'

      {
        File.join(gem_home, 'gems', spec.full_name) => spec.full_gem_path,
        File.join(gem_home, 'specifications', "#{spec.full_name}.gemspec") => spec.loaded_from,
      }.each do |destination, source|
        FileUtils.mkdir_p(File.dirname(destination))
        File.symlink(source, destination)
      end
      spec.executables.each do |executable|
        FileUtils.mkdir_p(File.join(gem_home, 'bin'))
        File.symlink(File.join(spec.full_gem_path, spec.bindir, executable), File.join(gem_home, 'bin', executable))
      end
      next if spec.extensions.empty?

      destination = File.join(gem_home, 'extensions', Gem::Platform.local.to_s, Gem.extension_api_version, spec.full_name)
      FileUtils.mkdir_p(File.dirname(destination))
      File.symlink(spec.extension_dir, destination)
    end
  end

  def teardown
    FileUtils.remove_entry(@project) if @project
  end

  def write(relative, code)
    path = File.join(@project, relative)
    FileUtils.mkdir_p(File.dirname(path))
    File.write(path, code)
  end

  def run_project(*command, extra_env: {}, directory: @project)
    # Keep personal and CI Bundler settings outside the synthetic project's configuration.
    env = Bundler.unbundled_env.reject { |key, _| key.start_with?('BUNDLE_') }
    env['BUNDLE_USER_HOME'] = File.join(@project, 'personal-bundle')
    env.merge!(extra_env)
    Open3.capture3(env, *command, chdir: directory, unsetenv_others: true)
  end

  def run_script(*arguments, **options)
    run_project(RbConfig.ruby, File.join(@project, '.tools/lint.rb'), *arguments, **options)
  end

  def assert_interface_call_lines(expected_lines)
    # GitHub Actions adds annotations to the ordinary log; each finding still counts once.
    [nil, 'synthetic'].each do |action|
      output, errors, status = run_script('manifests/site.pp', extra_env: { 'GITHUB_ACTION' => action })
      refute status.success?, output + errors
      expected = expected_lines.map { |line| "#{File.realpath(File.join(@project, 'manifests/site.pp'))}:#{line}" }
      actual = output.scan(/^(.+:\d+):\d+: project_interface_calls: warning:/).flatten
      assert_equal expected, actual, output + errors

      annotations = output.lines.grep(/^::warning .* \(check: project_interface_calls\)$/)
      assert_equal(action ? expected_lines.length : 0, annotations.length, output + errors)
    end
  end

  def test_readme_entry_point_checks_only_own_files_and_ignores_personal_configuration
    # Redirect only Ruby's home lookup in the subprocess; never write to the account's personal configuration.
    write('personal/.puppet-lint.rc', "--invalid-personal-option\n--fix\n")
    write('personal_lookup.rb', <<~RUBY)
      def Dir.home(*) = #{File.join(@project, 'personal').inspect}
      module SyntheticLintHome
        def expand_path(path, *arguments)
          return File.join(Dir.home, '.puppet-lint.rc') if path == '~/.puppet-lint.rc'

          super
        end
      end
      File.singleton_class.prepend(SyntheticLintHome)
    RUBY
    env = { 'RUBYOPT' => "-r#{File.join(@project, 'personal_lookup.rb')}" }
    output, errors, status = run_script(extra_env: env)
    assert status.success?, output + errors
    assert_includes output, '2 own manifests'

    script = File.join(@project, '.tools/lint.rb')
    original = File.read(script)
    File.write(script, original.sub("'--no-config', ", ''))
    output, errors, status = run_script(extra_env: env)
    refute status.success?, output + errors
    assert_includes output, 'invalid-personal-option'
    File.write(script, original)

    output, errors, status = run_script('modules/profile/manifests/init.pp', extra_env: env, directory: @tooling)
    assert status.success?, output + errors
    assert_includes output, '1 own manifests'

    write('manifests/site.pp', "$values = [1] + [2]\n")
    output, errors, status = run_script('manifests/site.pp', extra_env: env)
    refute status.success?, output + errors
    assert_includes output, "#{@project}/manifests/site.pp:1:"
    assert_includes output, 'project_arrays'
    assert_equal "$values = [1] + [2]\n", File.read(File.join(@project, 'manifests/site.pp'))
    assert_equal "raise 'The consumer bundle must not be loaded'\n", File.read(File.join(@project, 'Gemfile'))
    refute File.exist?(File.join(@project, 'Gemfile.lock'))
    refute File.exist?(File.join(@project, '.cache'))
    refute File.exist?(File.join(@tooling, '.cache'))
  end

  def test_readme_entry_point_uses_the_bundle_path_from_the_ci_environment
    File.write(File.join(@tooling, '.bundle/config'), "BUNDLE_PATH: missing-gems\n")
    output, errors, status = run_script(extra_env: {
      'BUNDLE_IGNORE_CONFIG' => '1',
      'BUNDLE_PATH' => 'vendor/bundle',
    })
    assert status.success?, output + errors
    assert_includes output, '2 own manifests'
    refute File.exist?(File.join(@project, '.cache'))
    refute File.exist?(File.join(@tooling, '.cache'))
  end

  def test_consumer_configuration_is_required_and_shared_changes_take_effect
    File.open(File.join(@tooling, '.puppet-lint.rc'), 'a') do |config|
      config.puts '--log-format=shared:%{check}:%{line}: %{message}'
    end
    write('manifests/site.pp', "$values = [1] + [2]\n")
    output, errors, status = run_script('manifests/site.pp')
    refute status.success?, output + errors
    assert_includes output, 'shared:project_arrays:1:'

    File.open(File.join(@project, '.puppet-lint.rc'), 'a') { |config| config.puts '--invalid-consumer-option' }
    output, errors, status = run_script
    refute status.success?, output + errors
    assert_includes output + errors, 'invalid-consumer-option'

    FileUtils.rm(File.join(@project, '.puppet-lint.rc'))
    output, errors, status = run_script
    refute status.success?, output + errors
    assert_includes errors, 'Missing project lint file'
  end

  def test_consumer_configuration_works_with_the_standard_cli_and_relative_manifest_paths
    env = {
      'BUNDLE_GEMFILE' => File.join(@tooling, 'Gemfile'),
      'BUNDLE_FROZEN' => 'true',
      'BUNDLE_VERSION' => 'system',
    }
    command = ['bundle', 'exec', 'puppet-lint', '--no-config', '--config', '.puppet-lint.rc', 'manifests/site.pp']
    write('manifests/site.pp', "$values = concat([1], [2])\n")
    output, errors, status = run_project(*command, extra_env: env)
    assert status.success?, output + errors

    write('manifests/site.pp', "$values = [1] + [2]\n")
    output, errors, status = run_project(*command, extra_env: env)
    refute status.success?, output + errors
    assert_includes output, 'manifests/site.pp:1:'
    assert_includes output, 'project_arrays'

    FileUtils.rm(File.join(@tooling, '.puppet-lint.rc'))
    output, errors, status = run_project(*command, extra_env: env)
    refute status.success?, output + errors
    assert_includes errors, 'Missing shared lint file'
  end

  def test_external_interfaces_follow_module_order_and_keep_dependencies_outside_style_scope
    write('manifests/site.pp', "class { 'profile': }\nclass { 'shared': }\n")
    assert_interface_call_lines([1, 2])

    # An earlier module shadows the whole later module, even when a nested manifest is absent.
    FileUtils.mkdir_p(File.join(@tooling, 'profile/manifests'))
    File.write(File.join(@tooling, 'profile/manifests/init.pp'), 'class profile {}')
    File.write(File.join(@tooling, 'profile/manifests/item.pp'), 'define profile::item (String $value) {}')
    write('manifests/site.pp', "class { 'profile': }\nprofile::item { 'synthetic': }\n")
    assert_interface_call_lines([1])

    script = File.join(@project, '.tools/lint.rb')
    File.write(script, File.read(script).sub("[File.join(project_root, 'modules'), lint_root]", "[lint_root, File.join(project_root, 'modules')]"))
    assert_interface_call_lines([2])
  end

  def test_readme_entry_point_requires_a_files_ignore_and_keeps_mount_validation_active
    [
      ['modules', false, nil],
      ['files', false, 'puppet_url_without_modules'],
      ['files', true, nil],
      ['invalid', true, 'project_puppet_urls'],
    ].each do |mount, ignore, expected_check|
      control = ignore ? ' # lint:ignore:puppet_url_without_modules' : ''
      write('manifests/site.pp', <<~PUPPET)
        file { '/tmp/synthetic-app.tar.gz':
          ensure => file,
          owner  => 'root',
          group  => 'root',
          mode   => '0600',
          source => 'puppet:///#{mount}/example/app.tar.gz',#{control}
        }
      PUPPET
      output, errors, status = run_script
      assert_includes output, '2 own manifests'
      if expected_check
        refute status.success?, output + errors
        checks = output.scan(/^.+:6:13: (\w+): warning:/).flatten
        assert_equal [expected_check], checks, output + errors
      else
        assert status.success?, output + errors
      end
      refute_includes output, 'project_suppressions'
    end
  end

  def test_explicit_modulepath_also_resolves_vendored_names_without_following_escaping_symlinks
    write('modules/stdlib/manifests/init.pp', 'class stdlib (String $value) {}')
    write('manifests/site.pp', "class { 'stdlib': }\n")
    output, errors, status = run_script('manifests/site.pp')
    refute status.success?, output + errors
    assert_includes output, 'project_interface_calls'

    write('outside/manifests/init.pp', 'class escaping (String $value) {}')
    File.symlink(File.join(@project, 'outside'), File.join(@project, 'modules/escaping'))
    write('manifests/site.pp', "class { 'escaping': }\n")
    output, errors, status = run_script('manifests/site.pp')
    assert status.success?, output + errors
    refute_includes output, 'project_interface_calls'
  end

  def test_missing_plugins_syntax_errors_and_empty_or_wrong_scope_fail
    write('manifests/site.pp', 'class broken (String $value = ) {}')
    output, errors, status = run_script
    refute status.success?, output + errors
    assert_includes output, 'Invalid Puppet syntax'

    FileUtils.rm(File.join(@tooling, '.tools/lint/lib/puppet-lint/plugins/resources.rb'))
    output, errors, status = run_script
    refute status.success?, output + errors
    assert_includes errors, 'resources.rb'

    output, errors, status = run_script('spec/fixtures/invalid.pp')
    refute status.success?, output + errors
    assert_includes errors, 'outside the own lint scope'
    %w[manifests/site.pp modules/profile/manifests/init.pp].each { |path| FileUtils.rm(File.join(@project, path)) }
    output, errors, status = run_script
    refute status.success?, output + errors
    assert_includes errors, 'No own Puppet manifests selected'
    FileUtils.rmdir(File.join(@project, 'manifests'))
    output, errors, status = run_script
    refute status.success?, output + errors
    assert_includes errors, 'Missing source directory'
  end

  def test_invalid_module_paths_fail_even_without_resource_calls
    script = File.join(@project, '.tools/lint.rb')
    original = File.read(script)
    ["['']", "['modules']", "[File.join(project_root, 'missing')]"].each do |paths|
      File.write(script, original.sub("[File.join(project_root, 'modules'), lint_root]", paths))
      write('manifests/site.pp', "$values = concat([1], [2])\n")
      output, errors, status = run_script('manifests/site.pp')
      refute status.success?, output + errors
      assert_includes errors, 'PROJECT_LINT_MODULEPATH'
    end
  end
end
