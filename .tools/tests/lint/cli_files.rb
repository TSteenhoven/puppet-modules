# frozen_string_literal: true

# Give each CLI scenario its own directory and create only synthetic files there.
module CliFiles
  def setup
    @directory = Dir.mktmpdir('lint_cli_')
  end

  def teardown
    FileUtils.remove_entry(@directory) if @directory
  end

  def write_file(relative, content)
    path = File.join(@directory, relative)
    FileUtils.mkdir_p(File.dirname(path))
    File.write(path, content)
    path
  end

  def write_source(content, path: 'example.pp')
    @file = write_file(path, content)
  end

  def source
    File.read(@file)
  end
end
