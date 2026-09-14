# frozen_string_literal: true

# Retain explicit exit-status, output and file-content checks around native CLI calls.
module CliAssertions
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
end
