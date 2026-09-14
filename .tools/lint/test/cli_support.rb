# frozen_string_literal: true

# Temporary files and subprocess assertions for native CLI integration tests.
module LintCliSupport
  include LintTestSupport

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

  def capture_cli(*arguments, **options)
    @output, @errors, @status = cli(*arguments, **options)
  end

  def assert_cli_success(*arguments, **options)
    capture_cli(*arguments, **options)
    assert @status.success?, @output + @errors
  end

  def assert_cli_failure(*arguments, **options)
    capture_cli(*arguments, **options)
    refute @status.success?, @output + @errors
  end

  def assert_cli_result(expected, *arguments, **options)
    capture_cli(*arguments, **options)
    assert_equal expected, @status.success?, @output + @errors
  end

  def diagnostics(output, check)
    output.lines.grep(/\A.+:\d+:\d+: #{Regexp.escape(check)}: (?:warning|error|fixed|ignored): /)
  end

  def assert_cli_stable(expected, *arguments, **options)
    [[], ['--fix']].each do |fix|
      assert_cli_success(*fix, *arguments, @file, **options)
      assert_empty @output
      assert_equal expected, source
    end
  end

  def assert_review_source(code, check, count: 1, options: [])
    write_source(code)
    assert_cli_failure('--fix', *options, @file)
    assert_equal count, diagnostics(@output, check).length, @output
    assert_equal code, source
  end

  def cli(*arguments, directory: LintTestSupport::ROOT, env: {}, project_config: true)
    options = project_config ? ['--no-config', '--config', '.puppet-lint.rc'] : []
    Open3.capture3(env, Gem.bin_path('puppet-lint', 'puppet-lint'), *options, *arguments, chdir: directory)
  end

  def copy_project_config(root)
    FileUtils.mkdir_p(File.join(root, '.tools/lint/config'))
    config = File.read(File.join(LintTestSupport::ROOT, '.puppet-lint.rc'))
    entry = File.join(Gem::Specification.find_by_name('puppet-lint-project').full_gem_path, 'lib/project_lint.rb')
    File.write(File.join(root, '.puppet-lint.rc'), config.sub('.tools/lint/lib/project_lint.rb', entry))
    FileUtils.cp(File.join(LintTestSupport::ROOT, '.tools/lint/config/puppet-lint.rc'),
                 File.join(root, '.tools/lint/config'))
  end
end
