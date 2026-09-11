require_relative 'test_helper'

class CliTest < Minitest::Test
  include LintTestSupport

  def cli(*arguments, directory: LintTestSupport::ROOT, env: {})
    Open3.capture3(env, Gem.bin_path('puppet-lint', 'puppet-lint'), *arguments, chdir: directory)
  end

  # Count the configured diagnostic lines; GitHub annotations repeat the same findings.
  def diagnostics(output, check)
    output.lines.grep(/\A.+:\d+:\d+: #{Regexp.escape(check)}: (?:warning|error|fixed|ignored): /)
  end

  def test_diagnostic_counts_are_independent_of_github_annotations
    Dir.mktmpdir('lint_github_annotations_') do |directory|
      file = File.join(directory, 'project_layout.pp')
      code = <<~'PUPPET'
        $values = [
              'first',
              'second',
        ]
        $other = [1] + [2]
      PUPPET
      [nil, 'synthetic_test'].each do |github_action|
        [[], ['--fix']].each do |options|
          File.write(file, code)
          output, errors, status = cli(*options, file, env: { 'GITHUB_ACTION' => github_action })
          refute status.success?, output + errors
          assert_equal 2, diagnostics(output, 'project_layout').length, output
          assert_equal 1, diagnostics(output, 'project_arrays').length, output
          assert_equal github_action ? 3 : 0, output.lines.grep(/\A::warning /).length, output
          assert_equal code, File.read(file)
        end
      end
    end
  end

  def test_default_and_project_checks_are_present_and_enabled
    refute_match(/--only-checks\b/, File.read('.puppet-lint.rc'))
    assert PuppetLint.configuration.puppet_url_without_modules_enabled?
    enabled = PuppetLint.configuration.checks.select { |check| PuppetLint.configuration.public_send("#{check}_enabled?") }
    %i[140chars documentation parameter_order selector_inside_resource single_quote_string_with_variables class_inherits_from_params_class project_arrays project_class_check_reuse project_comment_spacing project_documentation project_files project_if_sections project_interface_calls project_layout project_monitoring_backend project_packages project_parameter_alignment project_parameter_order project_positive_flow project_puppet_urls project_resource_sections project_shell project_suppressions project_templates project_variable_sections].each do |check|
      assert_includes enabled, check
    end
    output, _, status = cli('--list-checks')
    assert status.success?
    enabled.each { |check| assert_includes output.lines.map(&:strip), check.to_s }
  end

  def test_puppet_source_ignore_keeps_the_additional_check_active_with_fix
    Dir.mktmpdir('lint_source_') do |directory|
      file = File.join(directory, 'source.pp')
      %w[files invalid].each do |mount|
        code = "$source = 'puppet:///#{mount}/example/app.tar.gz' # lint:ignore:puppet_url_without_modules\n"
        File.write(file, code)
        output, errors, status = cli('--fix', file)
        if mount == 'invalid'
          refute status.success?, output + errors
          assert_includes output, 'project_puppet_urls'
        else
          assert status.success?, output + errors
        end
        assert_equal code, File.read(file)
      end
    end
  end

  def test_section_checks_fail_without_inventing_comments_with_fix
    Dir.mktmpdir('lint_sections_') do |directory|
      file = File.join(directory, 'sections.pp')
      code = <<~'PUPPET'
        $enabled = true
        # Keep the synthetic notification conditional.
        if $enabled {
          notify { 'first': }
        }
        notify { 'second': }
      PUPPET
      File.write(file, code)
      output, errors, status = cli('--fix', file)
      refute status.success?, errors
      assert_includes output, 'project_comment_spacing'
      assert_includes output, 'project_resource_sections'
      assert_equal code, File.read(file)
    end
  end

  def test_opening_brace_spacing_fails_even_after_a_line_length_suppression
    Dir.mktmpdir('lint_opening_braces_') do |directory|
      file = File.join(directory, 'spacing.pp')
      code = <<~'PUPPET'
        # Check the outer prerequisite.
        if $active { # lint:ignore:140chars

          # Check the nested prerequisite.
          if $ready {
            notice('Ready')
          }
        }
      PUPPET
      [[], ['--fix']].each do |options|
        File.write(file, code)
        output, errors, status = cli(*options, file)
        refute status.success?, output + errors
        assert_equal 1, diagnostics(output, 'project_layout').length, output
        assert_includes output, ':3:1: project_layout: warning: Remove blank lines immediately after an opening brace'
        assert_equal code, File.read(file)
      end

      File.write(file, code.sub("\n\n", "\n"))
      output, errors, status = cli(file)
      assert status.success?, output + errors
    end
  end

  def test_array_indentation_fails_with_and_without_fix_and_accepts_the_corrected_layout
    Dir.mktmpdir('lint_array_indentation_') do |directory|
      file = File.join(directory, 'arrays.pp')
      code = <<~'PUPPET'
        $command = join([
              'printf "%s"',
              'synthetic',
            ], ' ')
      PUPPET
      [[], ['--fix']].each do |options|
        File.write(file, code)
        output, errors, status = cli(*options, file)
        refute status.success?, output + errors
        assert_equal 3, diagnostics(output, 'project_layout').length, output
        assert_includes output, ':2:7: project_layout: warning: Use 2 leading spaces for the array element'
        assert_includes output, ':4:5: project_layout: warning: Use 0 leading spaces for the closing array bracket'
        assert_equal code, File.read(file)
      end

      File.write(file, code.gsub(/^      /, '  ').sub('    ]', ']'))
      output, errors, status = cli(file)
      assert status.success?, output + errors
    end
  end

  def test_variable_sections_fail_without_inventing_an_explanation_with_fix
    Dir.mktmpdir('lint_variables_') do |directory|
      file = File.join(directory, 'variables.pp')
      code = <<~'PUPPET'
        # Prepare the label.
        $first = 'example'
        $second = $first
        $timeout = 30
      PUPPET
      File.write(file, code)
      output, errors, status = cli('--fix', file)
      refute status.success?, errors
      assert_equal 1, diagnostics(output, 'project_variable_sections').length, output
      assert_equal code, File.read(file)
    end
  end

  def test_if_sections_fail_without_inventing_or_moving_comments_with_fix
    Dir.mktmpdir('lint_conditions_') do |directory|
      file = File.join(directory, 'conditions.pp')
      codes = [
        "if $active { notice('Active') }\n",
        "$enabled = true\n$active = $enabled\n\n# Explain the active operation.\nif $active { notice('Active') }\n",
      ]
      codes.each do |code|
        File.write(file, code)
        output, errors, status = cli('--fix', file)
        refute status.success?, errors
        assert_equal 1, diagnostics(output, 'project_if_sections').length, output
        assert_equal code, File.read(file)
        File.write(file, "# Explain the operation and its prerequisites.\n#{code}")
        output, errors, status = cli(file)
        assert status.success?, output + errors
      end
    end
  end

  def test_block_variable_sections_offer_a_review_hint_without_moving_assignments_with_fix
    Dir.mktmpdir('lint_block_variables_') do |directory|
      file = File.join(directory, 'variables.pp')
      code = <<~'PUPPET'
        # Prepare arguments only for the active check.
        if $active {
          $config_shell = stdlib::shell_escape($config)

          # Escape the check limits.
          $timeout_shell = stdlib::shell_escape(String($timeout))
        }
      PUPPET
      File.write(file, code)
      output, errors, status = cli('--fix', file)
      refute status.success?, output + errors
      assert_equal 1, diagnostics(output, 'project_variable_sections').length, output
      assert_includes output, 'section at line 5'
      assert_includes output, 'checking purpose and evaluation order'
      assert_equal code, File.read(file)

      corrected = code.sub("  $config_shell = stdlib::shell_escape($config)\n\n", '')
      corrected = corrected.sub('  # Escape the check limits.', "  # Escape the configuration path and check limits.\n  $config_shell = stdlib::shell_escape($config)")
      File.write(file, corrected)
      output, errors, status = cli(file)
      assert status.success?, output + errors
    end
  end

  def test_branch_order_fails_without_rewriting_conditions_with_fix
    Dir.mktmpdir('lint_branches_') do |directory|
      file = File.join(directory, 'branches.pp')
      code = <<~'PUPPET'
        # Select the appropriate handling for the current state.
        if $active {
          notice('Unavailable')
        } else {
          # Prepare the fallback values used by the alternative path.
          $first = 1
          $second = 2
        }
      PUPPET
      File.write(file, code)
      output, errors, status = cli('--fix', file)
      refute status.success?, errors
      assert_equal 1, diagnostics(output, 'project_positive_flow').length, output
      assert_equal code, File.read(file)
    end
  end

  def test_validation_structure_checks_enclosing_blocks_without_rewriting_them
    Dir.mktmpdir('lint_validation_flow_') do |directory|
      file = File.join(directory, 'example.pp')
      code = <<~'PUPPET'
        class example {
          if $parent {
            if $valid {
              notice('Valid')
            } else {
              warning('Invalid settings')
            }
          } else {
            fail('Missing parent')
          }
          notify { 'outside-validation': }
        }
      PUPPET
      File.write(file, code)
      output, errors, status = cli('--only-checks', 'project_positive_flow', '--fix', file)
      refute status.success?, output + errors
      assert_includes output, 'no implementation may follow'
      assert_equal 2, diagnostics(output, 'project_positive_flow').length, output
      assert_equal code, File.read(file)

      corrected = code.sub("  notify { 'outside-validation': }\n", '')
      corrected = corrected.sub("      notice('Valid')", "      notice('Valid')\n      notify { 'inside-validation': }")
      File.write(file, corrected)
      output, errors, status = cli('--only-checks', 'project_positive_flow', file)
      assert status.success?, output + errors
    end
  end

  def test_monitoring_backend_check_does_not_rewrite_backend_conditions_with_fix
    Dir.mktmpdir('lint_monitoring_backend_') do |directory|
      file = File.join(directory, 'monitoring.pp')
      code = <<~'PUPPET'
        # Register the check when monitoring is active.
        $active = $basic_settings::monitoring::package == 'synthetic_backend'
        if $active {
          basic_settings::monitoring_custom { 'synthetic': }
        }
      PUPPET
      File.write(file, code)
      output, errors, status = cli('--fix', file)
      refute status.success?, output + errors
      assert_equal 1, diagnostics(output, 'project_monitoring_backend').length, output
      assert_equal code, File.read(file)
      File.write(file, code.sub("== 'synthetic_backend'", "!= 'none'"))
      output, errors, status = cli(file)
      assert status.success?, output + errors
    end
  end

  def test_class_check_reuse_does_not_change_evaluation_order_with_fix
    Dir.mktmpdir('lint_class_checks_') do |directory|
      file = File.join(directory, 'example.pp')
      declarations = [
        "$enabled = defined(Class['synthetic']); notice($enabled)",
        "notice(defined(Class['synthetic'])); include synthetic; notice(defined(Class['synthetic']))",
      ]
      declarations.each do |body|
        code = "class example { #{body} }\n"
        File.write(file, code)
        output, errors, status = cli('--only-checks', 'project_class_check_reuse', '--fix', file)
        refute status.success?, output + errors
        assert_equal 1, diagnostics(output, 'project_class_check_reuse').length, output
        assert_equal code, File.read(file)
      end
    end
  end

  def test_class_check_consumers_are_resolved_in_the_configured_modulepath
    Dir.mktmpdir('lint_class_consumers_') do |directory|
      FileUtils.mkdir_p(File.join(directory, 'example/manifests'))
      FileUtils.mkdir_p(File.join(directory, 'example/templates'))
      FileUtils.mkdir_p(File.join(directory, 'consumer/manifests'))
      file = File.join(directory, 'example/manifests/init.pp')
      template = File.join(directory, 'example/templates/state.erb')
      File.write(file, <<~'PUPPET')
        class example {
          $enabled = defined(Class['synthetic'])
          notice($enabled, template('example/state.erb'))
        }
      PUPPET
      File.write(template, '<%= @enabled %>')
      command = [Gem.bin_path('puppet-lint', 'puppet-lint'), '--only-checks', 'project_class_check_reuse', file]
      env = { 'PROJECT_LINT_MODULEPATH' => directory }
      output, errors, status = Open3.capture3(env, *command)
      assert status.success?, output + errors

      File.write(template, '@enabled<%# @enabled is only mentioned in a comment. %>')
      output, errors, status = Open3.capture3(env, *command)
      refute status.success?, output + errors
      assert_includes output, 'used only once'

      File.write(File.join(directory, 'consumer/manifests/init.pp'), 'class consumer { notice($example::enabled) }')
      output, errors, status = Open3.capture3(env, *command)
      assert status.success?, output + errors
    end
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
    Dir.mktmpdir('lint_cli_') do |directory|
      copy_linter(directory)
      file = File.join(directory, 'new.pp')
      File.write(file, "$values = concat([1], [2])\n")
      output, _, status = cli('.', directory: directory)
      assert status.success?, output
      File.write(file, "$values = [1] + [2]\n")
      output, _, status = cli('.', directory: directory)
      refute status.success?
      assert_includes output, 'new.pp:1:'
      assert_includes output, 'project_arrays'
    end
  end

  def test_invalid_options_and_missing_plugin_files_fail
    output, _, status = cli('--no-config', '--no-nonexistent-check', '.')
    refute status.success?
    assert_includes output, 'invalid option'
    _, _, status = cli('--no-config', '--load=.tools/tests/lint/missing-plugin.rb', '.')
    refute status.success?
  end

  def test_vendored_gitlinks_are_the_only_excluded_module_directories
    entries, status = Open3.capture2('git', 'ls-files', '--stage', '-z')
    assert status.success?
    gitlinks = entries.split("\0").select { |entry| entry.start_with?('160000 ') }.map { |entry| entry.split("\t", 2).last }.sort
    ignored = PuppetLint.configuration.ignore_paths
    expected = (gitlinks + %w[vendor/bundle]).flat_map { |path| ["./#{path}/*", "#{path}/*"] }
    expected.concat(%w[./*/templates/*.yaml */templates/*.yaml ./*/templates/*.yml */templates/*.yml])
    assert_equal expected.sort, ignored.sort
    gitlinks.each { |path| assert ignored.any? { |pattern| File.fnmatch(pattern, "./#{path}/manifests/init.pp") } }
    %w[./example/manifests/init.pp ./examples/example.pp].each do |path|
      refute ignored.any? { |pattern| File.fnmatch(pattern, path) }
    end
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
