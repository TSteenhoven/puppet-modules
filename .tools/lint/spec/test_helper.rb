require 'minitest/autorun'
require 'open3'
require 'tmpdir'
require 'puppet-lint'

# Tests use the ordinary CLI option loader and the same local plugin files as a developer invocation.
PuppetLint::OptParser.build(['--no-config', '--config', '.puppet-lint.rc'])

module ProjectLint
  ROOT = File.expand_path('../../..', __dir__)
end

class Minitest::Test
  # Reuse the CLI exclusions for repository regression inputs instead of maintaining a second module list.
  def project_files(pattern)
    Dir[pattern].select do |path|
      File.file?(path) && !File.symlink?(path) && PuppetLint.configuration.ignore_paths.none? { |ignored| File.fnmatch(ignored, path) }
    end
  end
end
