require_relative 'test_helper'

class CliTest < Minitest::Test
  def cli(*arguments)
    Open3.capture3(Gem.bin_path('puppet-lint', 'puppet-lint'), *arguments)
  end

  def test_default_and_project_checks_are_present_and_enabled
    refute_match(/--only-checks\b/, File.read('.puppet-lint.rc'))
    enabled = PuppetLint.configuration.checks.select { |check| PuppetLint.configuration.public_send("#{check}_enabled?") }
    %i[140chars documentation parameter_order selector_inside_resource single_quote_string_with_variables class_inherits_from_params_class project_arrays project_documentation project_files project_interface_calls project_layout project_packages project_parameter_alignment project_parameter_order project_positive_flow project_shell project_suppressions project_templates].each do |check|
      assert_includes enabled, check
    end
    output, _, status = cli('--list-checks')
    assert status.success?
    enabled.each { |check| assert_includes output.lines.map(&:strip), check.to_s }
  end

  def test_a_new_default_check_is_not_disabled_by_the_project_configuration
    Dir.mktmpdir('lint_new_check_') do |directory|
      plugin = File.join(directory, 'future_check.rb')
      file = File.join(directory, 'new.pp')
      # Load before CLI configuration, as a new built-in check or an installed plugin would be loaded after an upgrade.
      File.write(plugin, <<~RUBY)
        require 'puppet-lint'
        PuppetLint.new_check(:future_default_check) do
          def check
            notify(:warning, message: 'New default check is active', line: 1, column: 1)
          end
        end
      RUBY
      File.write(file, "$values = concat([1], [2])\n")
      output, errors, status = Open3.capture3(RbConfig.ruby, '-r', plugin, Gem.bin_path('puppet-lint', 'puppet-lint'), file)
      refute status.success?, errors
      assert_includes output, 'future_default_check'
    end
  end

  def test_cli_discovers_new_first_party_files_and_fails_on_a_project_check
    Dir.mktmpdir('lint_cli_', ProjectLint::ROOT) do |directory|
      file = File.join(directory, 'new.pp')
      File.write(file, "$values = concat([1], [2])\n")
      output, _, status = cli('.')
      assert status.success?, output
      File.write(file, "$values = [1] + [2]\n")
      output, _, status = cli('.')
      refute status.success?
      assert_includes output, 'new.pp:1:'
      assert_includes output, 'project_arrays'
    end
  end

  def test_invalid_options_and_missing_plugin_files_fail
    output, _, status = cli('--no-config', '--no-nonexistent-check', '.')
    refute status.success?
    assert_includes output, 'invalid option'
    _, _, status = cli('--no-config', '--load=.tools/lint/spec/missing-plugin.rb', '.')
    refute status.success?
  end

  def test_vendored_gitlinks_are_the_only_excluded_module_directories
    entries, status = Open3.capture2('git', 'ls-files', '--stage', '-z')
    assert status.success?
    gitlinks = entries.split("\0").select { |entry| entry.start_with?('160000 ') }.map { |entry| entry.split("\t", 2).last }.sort
    declared, status = Open3.capture2('git', 'config', '--file', '.gitmodules', '--get-regexp', '^submodule\..*\.path$')
    assert status.success?
    assert_equal gitlinks, declared.lines.map { |line| line.split(' ', 2).last.strip }.sort
    ignored = PuppetLint.configuration.ignore_paths
    expected = (gitlinks + %w[vendor/bundle .tools/lint/spec/fixtures]).flat_map { |path| ["./#{path}/*", "#{path}/*"] }
    expected.concat(%w[./*/templates/*.yaml */templates/*.yaml ./*/templates/*.yml */templates/*.yml])
    assert_equal expected.sort, ignored.sort
    gitlinks.each { |path| assert ignored.any? { |pattern| File.fnmatch(pattern, "./#{path}/manifests/init.pp") } }
    refute_empty project_files('./**/*.pp')
  end

  def test_invalid_puppet_is_an_error_without_a_custom_execution_layer
    Dir.mktmpdir('lint_syntax_') do |directory|
      file = File.join(directory, 'broken.pp')
      File.write(file, 'class example (String $value = ) {}')
      output, _, status = cli(file)
      refute status.success?
      assert_includes output, 'Invalid Puppet syntax'
    end
  end
end
