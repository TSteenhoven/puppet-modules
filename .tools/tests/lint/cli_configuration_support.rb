# frozen_string_literal: true

# Exercise personal option effects and the explicit configuration boundary separately.
module CliConfigurationSupport
  def personal_options
    { directory: @directory, env: @personal_environment }
  end

  def prepare_personal_configuration
    copy_linter(@directory)
    @original = "$values = [\n      \"synthetic\",\n]\n"
    @fixed = "$values = [\n  'synthetic',\n]\n"
    write_source(@original)
    write_file('system.rc', "--no-double_quoted_strings-check\n")
    write_file('personal.rc', "--fix\n--no-140chars-check\n")
    hook = write_file('option_files.rb', File.read(File.join(__dir__, 'fixtures/option_files.rb')))
    @personal_environment = { 'SYNTHETIC_LINT_CONFIG_ROOT' => @directory,
                              'RUBYOPT' => [ENV.fetch('RUBYOPT', nil), "-r#{hook}"].compact.join(' ') }
  end

  def assert_personal_fix_effect
    assert_cli_success('.', **personal_options, project_config: false)
    assert_equal @original.sub('      ', '  '), source
    assert_includes @output, 'fixed'
    refute_includes @output, 'double_quoted_strings'
  end

  def assert_explicit_configuration_boundary
    write_source(@original)
    assert_cli_failure('.', **personal_options)
    assert_equal @original, source
    assert_includes @output, 'project_layout'
    assert_includes @output, 'double_quoted_strings'
    refute_includes @output, ': fixed:'
  end

  def assert_explicit_fix
    assert_cli_success('--fix', '.', **personal_options)
    assert_equal @fixed, source
    assert_cli_stable(@fixed, **personal_options)
  end

  def assert_invalid_configuration_boundaries
    %w[system.rc personal.rc].each { |path| write_file(path, "--invalid-synthetic-option\n") }
    assert_cli_success(@file, **personal_options)
    File.open(File.join(@directory, '.puppet-lint.rc'), 'a') { |config| config.puts '--invalid-project-option' }
    assert_cli_failure(@file, **personal_options)
    assert_includes @output, 'invalid-project-option'
  end
end
