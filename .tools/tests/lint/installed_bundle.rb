# frozen_string_literal: true

require 'bundler'

# Reuse the locked gems in a temporary project without downloads or developer-bundle changes.
class InstalledBundle
  def initialize(tooling)
    @tooling = tooling
    @gem_home = File.join(tooling, 'vendor/bundle', 'ruby', RbConfig::CONFIG.fetch('ruby_version'))
  end

  def prepare
    FileUtils.mkdir_p(File.join(@tooling, '.bundle'))
    File.write(File.join(@tooling, '.bundle/config'), "BUNDLE_PATH: vendor/bundle\n")
    Bundler.load.specs.each { |spec| link_spec(spec) unless spec.name == 'bundler' }
  end

  def link(source, *destination)
    target = File.join(@gem_home, *destination)
    FileUtils.mkdir_p(File.dirname(target))
    File.symlink(source, target)
  end

  def link_spec(spec)
    link(spec.full_gem_path, 'gems', spec.full_name)
    link(spec.loaded_from, 'specifications', "#{spec.full_name}.gemspec")
    link_executables(spec)
    return if spec.extensions.empty?

    link(spec.extension_dir, 'extensions', Gem::Platform.local.to_s, Gem.extension_api_version, spec.full_name)
  end

  def link_executables(spec)
    spec.executables.each do |executable|
      link(File.join(spec.full_gem_path, spec.bindir, executable), 'bin', executable)
    end
  end
end
