require 'minitest/autorun'
require 'open3'
require 'tmpdir'
require 'fileutils'
require_relative '../../lint/lib/config'

module LintTestSupport
  ROOT = File.expand_path('../../..', __dir__)

  # Integration tests copy the real implementation into an isolated project layout.
  def copy_linter(root)
    FileUtils.mkdir_p(File.join(root, '.tools/lint'))
    FileUtils.cp_r(File.join(ROOT, '.tools/lint/lib'), File.join(root, '.tools/lint'))
    %w[.puppet-lint.rc Gemfile Gemfile.lock].each do |name|
      FileUtils.cp(File.join(ROOT, name), root)
    end
  end
end
