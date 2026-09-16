# frozen_string_literal: true

require 'bundler'

# Build a gem and exercise it through a separate, offline consumer bundle.
module InstalledGemSupport
  def setup
    @project = Dir.mktmpdir('lint-consumer-')
    @gem_home = File.join(@project, 'installed gems')
    @env = Bundler.unbundled_env.reject { |key, _| key.start_with?('BUNDLE_') || key == 'DEBUG' }
    prepare_environment
    install_gem
    prepare_bundle
    prepare_project
  end

  def prepare_environment
    @env['PATH'] = [Gem.bindir, @env.fetch('PATH')].join(File::PATH_SEPARATOR)
    @env.merge!('BUNDLE_IGNORE_CONFIG' => '1', 'BUNDLE_USER_HOME' => File.join(@project, 'bundle home'),
                'GEM_HOME' => @gem_home, 'GEM_PATH' => ([@gem_home] + Gem.path).join(File::PATH_SEPARATOR))
  end

  def reverse_modulepath
    @env['PROJECT_LINT_MODULEPATH'] = @env.fetch('PROJECT_LINT_MODULEPATH').split(':').reverse.join(':')
  end

  def install_gem
    package = File.join(@project, 'lint-project.gem')
    gem_root = File.join(LintTestSupport::ROOT, '.tools/lint')
    run_success('gem', 'build', 'lint-project.gemspec', '--output', package, directory: gem_root)
    run_success('gem', 'install', '--local', '--ignore-dependencies', '--no-document', '--install-dir', @gem_home,
                package)
  end

  def prepare_bundle
    write('Gemfile', <<~RUBY)
      source 'https://rubygems.org'
      gem 'lint-project', '= 0.1.2', require: false
    RUBY
    # Seed the consumer resolution with the tested dependency versions, then let Bundler resolve the installed gem.
    FileUtils.cp(File.join(LintTestSupport::ROOT, 'Gemfile.lock'), File.join(@project, 'Gemfile.lock'))
    run_success('bundle', 'install', '--local')
    run_success('bundle', 'info', '--path', 'lint-project')
    @installed = @output.strip
    @env['BUNDLE_FROZEN'] = 'true'
  end

  def prepare_project
    write('.puppet-lint.rc', "--ignore-paths=dependencies/*,vendor/*,spec/*\n")
    write('manifests/site.pp', "$values = concat([1], [2])\n")
    write('modules/profile/manifests/init.pp', 'class profile (String $value) {}')
    write('dependencies/shared/manifests/init.pp', 'class shared (String $value) {}')
    write('spec/invalid.pp', "$values = [1] + [2]\n")
    @env['PROJECT_LINT_MODULEPATH'] = [File.join(@project, 'modules'), File.join(@project, 'dependencies')].join(':')
  end

  def teardown
    FileUtils.remove_entry(@project) if @project
  end

  def write(relative, content)
    path = File.join(@project, relative)
    FileUtils.mkdir_p(File.dirname(path))
    File.write(path, content)
  end

  def read(relative)
    File.read(File.join(@project, relative))
  end

  def command(*command, directory: @project)
    @output, @errors, @status = Open3.capture3(@env, *command, chdir: directory, unsetenv_others: true)
  end

  def run_success(*command, **options)
    command(*command, **options)
    assert @status.success?, @output + @errors
  end

  def lint(*arguments)
    command('bundle', 'exec', 'puppet-lint', '--no-config',
            '--load', File.join(@installed, 'lib/project_lint.rb'),
            '--config', File.join(@installed, 'config/puppet-lint.rc'),
            '--config', '.puppet-lint.rc', *arguments)
  end
end
