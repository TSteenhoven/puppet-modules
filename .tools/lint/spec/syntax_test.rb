require_relative 'test_helper'
require 'erb'

class SyntaxTest < Minitest::Test
  def test_manifests_with_the_puppet_parser_cli
    files = project_files('./**/*.pp')
    refute_empty files
    _, errors, status = Open3.capture3(Gem.bin_path('openvox', 'puppet'), 'parser', 'validate', *files)
    assert status.success?, errors
  end

  def test_metadata_with_the_existing_metadata_json_lint_cli
    files = project_files('./*/metadata.json')
    refute_empty files
    files.each do |path|
      output, errors, status = Open3.capture3(Gem.bin_path('metadata-json-lint', 'metadata-json-lint'), path)
      assert status.success?, "#{path}: #{output}#{errors}"
    end
  end

  def test_erb_generated_ruby_and_static_shell_syntax
    # YAML-named ERB templates are not YAML input for puppet-lint; validate their generated Ruby here as well.
    Dir['./*/templates/**/*'].select { |path| File.file?(path) && !File.symlink?(path) }.each do |path|
      _, errors, status = Open3.capture3(RbConfig.ruby, '-c', stdin_data: ERB.new(File.read(path), trim_mode: '-').src)
      assert status.success?, "#{path}: #{errors}"
    end
    project_files('./*/files/**/*').each do |path|
      first = File.open(path, 'rb') { |file| file.gets }
      next unless first && first.match?(/\A#!.*\b(?:sh|bash)\b/)

      interpreter = first.match?(/\bbash\b/) ? '/bin/bash' : '/bin/sh'
      _, errors, status = Open3.capture3(interpreter, '-n', path)
      assert status.success?, "#{path}: #{errors}"
    end
  end
end
