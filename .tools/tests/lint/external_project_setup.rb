# frozen_string_literal: true

require_relative 'installed_bundle'

# Assemble the documented downstream layout with synthetic manifests and isolated gems.
module ExternalProjectSetup
  TOOLING_PATH = 'dependencies/shared modules/puppet-modules'

  def setup
    @project = Dir.mktmpdir('external-lint-')
    @tooling = File.join(@project, TOOLING_PATH)
    copy_linter(@tooling)
    prepare_entry_point
    prepare_manifests
    InstalledBundle.new(@tooling).prepare
  end

  def teardown
    FileUtils.remove_entry(@project) if @project
  end

  def prepare_entry_point
    readme = File.read(File.join(LintTestSupport::ROOT, '.tools/lint/README.md'))
    script = readme[/^```ruby\n(.*?)^```/m, 1]
    refute_nil script
    write('.tools/lint.rb', script.sub("'global-modules'", TOOLING_PATH.inspect))
    config = readme[/^```text\n(--load=.*?)^```/m, 1]
    refute_nil config
    write('.puppet-lint.rc', config.sub('global-modules/', "#{TOOLING_PATH}/"))
  end

  def prepare_manifests
    write('modules/profile/manifests/init.pp', fixture(:profile, scenario: '_setup'))
    write('manifests/site.pp', fixture(:site, scenario: '_setup'))
    write_shared('shared/manifests/init.pp', 'class shared (String $value) {}')
    %w[spec/fixtures/invalid.pp modules/vendor/manifests/init.pp vendor/bundle/invalid.pp].each do |path|
      write(path, "$values = [1] + [2]\n")
    end
    write('Gemfile', "raise 'The consumer bundle must not be loaded'\n")
  end
end
