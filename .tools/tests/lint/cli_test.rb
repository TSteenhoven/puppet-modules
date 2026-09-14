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
          expected_annotations = options.empty? ? 3 : 1
          assert_equal github_action ? expected_annotations : 0, output.lines.grep(/\A::warning /).length, output
          assert_equal options.empty? ? code : code.gsub('      ', '  '), File.read(file)
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
    assert_includes enabled, :project_resource_references
    assert_includes enabled, :project_documentation_layout
  end

  def test_documentation_fix_works_with_standard_checks_and_preserves_code_fixes
    Dir.mktmpdir('lint_documentation_') do |directory|
      FileUtils.mkdir_p(File.join(directory, 'example/manifests'))
      file = File.join(directory, 'example/manifests/init.pp')
      code = <<~PUPPET
        # @summary Manages the example.
        #
        # lint:ignore:140chars
        # #{('A description with a documented default. ' * 5).strip}
        # lint:endignore
        #
        # @example Include the class
        #   include example
        #
        # @api public
        class example {
          # Select the example value.
          $value = "synthetic"
        }
      PUPPET
      File.write(file, code)
      output, errors, status = cli('--fix', file)
      assert status.success?, output + errors
      fixed = File.read(file)
      refute_includes fixed, 'lint:ignore:140chars'
      assert_includes fixed, "$value = 'synthetic'"
      assert_includes fixed, "# @example Include the class\n#   include example\n"
      output, errors, status = cli('--fix', file)
      assert status.success?, output + errors
      assert_equal fixed, File.read(file)
      assert_empty diagnostics(output, 'project_documentation_layout')
    end
  end

  def test_documentation_fix_requires_a_rescan_for_original_standard_length_findings
    Dir.mktmpdir('lint_documentation_length_') do |directory|
      FileUtils.mkdir_p(File.join(directory, 'example/manifests'))
      file = File.join(directory, 'example/manifests/init.pp')
      code = "# @summary Manages the example.\n#\n# #{('A description with a default. ' * 6).strip}\n#\n# @example Include the class\n#   include example\n#\n# @api public\nclass example {}\n"
      File.write(file, code)
      output, errors, status = cli('--fix', file)
      refute status.success?, output + errors
      assert_equal 1, diagnostics(output, '140chars').length
      refute_equal code, File.read(file)
      output, errors, status = cli(file)
      assert status.success?, output + errors
      assert_empty diagnostics(output, 'project_documentation_layout')
    end
  end

  def test_scoped_documentation_fix_keeps_unsafe_summary_and_fails
    Dir.mktmpdir('lint_documentation_review_') do |directory|
      file = File.join(directory, 'example.pp')
      code = "# @summary #{('A description with a default. ' * 6).strip}\nclass example {}\n"
      File.write(file, code)
      output, errors, status = cli('--only-checks', 'project_documentation_layout', '--fix', file)
      refute status.success?, output + errors
      assert_includes output, '[review]'
      assert_equal code, File.read(file)
    end
  end

  def test_resource_references_fix_works_with_standard_checks_and_is_idempotent
    Dir.mktmpdir('lint_references_') do |directory|
      file = File.join(directory, 'references.pp')
      File.write(file, "Notify['target'] -> [Package[\"zulu\"], Package[\"alpha\"], Service['nginx'], Service['apache2']]\n")
      output, errors, status = cli(file)
      refute status.success?, output + errors
      assert_equal 2, diagnostics(output, 'project_resource_references').length

      output, errors, status = cli('--fix', file)
      assert status.success?, output + errors
      expected = "Notify['target'] -> [Package['alpha', 'zulu'], Service['apache2', 'nginx']]\n"
      assert_equal expected, File.read(file)
      output, errors, status = cli('--fix', file)
      assert status.success?, output + errors
      assert_empty diagnostics(output, 'project_resource_references')
      assert_equal expected, File.read(file)
    end
  end

  def test_resource_references_fix_preserves_comments_and_keeps_the_warning
    Dir.mktmpdir('lint_reference_comments_') do |directory|
      file = File.join(directory, 'references.pp')
      code = <<~'PUPPET'
        $refs = [
          File['/tmp/z'], # Keep the reason attached to this resource.
          File['/tmp/a'],
        ]
      PUPPET
      File.write(file, code)
      output, errors, status = cli('--fix', file)
      refute status.success?, output + errors
      assert_equal 1, diagnostics(output, 'project_resource_references').length
      assert_includes output, '[review]'
      assert_equal code, File.read(file)
    end
  end

  def test_single_reference_array_is_removed_with_standard_fixes
    Dir.mktmpdir('lint_single_reference_') do |directory|
      file = File.join(directory, 'example.pp')
      code = "# Declare the example dependency.\nnotify { 'example':\n  require => [\n      Package[\"a\",\"b\"],\n  ],\n}\n"
      expected = "# Declare the example dependency.\nnotify { 'example':\n  require => Package['a', 'b'],\n}\n"
      File.write(file, code)
      output, errors, status = cli(file)
      refute status.success?, output + errors
      assert_equal 1, diagnostics(output, 'project_resource_references').length
      assert_equal code, File.read(file)
      output, errors, status = cli('--fix', file)
      assert status.success?, output + errors
      assert_equal expected, File.read(file)
      ProjectLint::Model.new(File.read(file))
      [[], ['--fix']].each do |options|
        output, errors, status = cli(*options, file)
        assert status.success?, output + errors
        assert_empty output
        assert_equal expected, File.read(file)
      end
    end
  end

  def test_parameter_alignment_uses_explicit_native_cli_fixing
    Dir.mktmpdir('lint_parameters_') do |directory|
      file = File.join(directory, 'parameters.pp')
      code = "class example (\n  String $a= 'value',\n  Optional[String] $label=undef,\n) {}\n"
      expected = "class example (\n  String           $a     = 'value',\n  Optional[String] $label = undef,\n) {}\n"
      File.write(file, code)
      arguments = ['--only-checks', 'project_parameter_alignment', file]
      output, errors, status = cli(*arguments)
      refute status.success?, output + errors
      assert_equal code, File.read(file)
      output, errors, status = cli('--fix', *arguments)
      assert status.success?, output + errors
      assert_includes output, ': fixed:'
      assert_equal expected, File.read(file)
      [[], ['--fix']].each do |options|
        output, errors, status = cli(*options, *arguments)
        assert status.success?, output + errors
        assert_empty output
        assert_equal expected, File.read(file)
      end
    end
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
      assert_equal code.sub("$enabled = true\n", "$enabled = true\n\n"), File.read(file)
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
        assert_equal !options.empty?, status.success?, output + errors
        assert_equal 1, diagnostics(output, 'project_layout').length, output
        kind = options.empty? ? 'warning' : 'fixed'
        assert_includes output, ":3:1: project_layout: #{kind}: Remove blank lines immediately after an opening brace"
        assert_equal options.empty? ? code : code.sub("\n\n", "\n"), File.read(file)
      end

      File.write(file, code.sub("\n\n", "\n"))
      output, errors, status = cli(file)
      assert status.success?, output + errors
    end
  end

  def test_array_indentation_is_reported_and_fixed_explicitly
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
        assert_equal !options.empty?, status.success?, output + errors
        assert_equal 3, diagnostics(output, 'project_layout').length, output
        kind = options.empty? ? 'warning' : 'fixed'
        assert_includes output, ":2:7: project_layout: #{kind}: Use 2 leading spaces for the array element"
        assert_includes output, ":4:5: project_layout: #{kind}: Use 0 leading spaces for the closing array bracket"
        assert_equal options.empty? ? code : code.gsub(/^      /, '  ').sub('    ]', ']'), File.read(file)
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
      code = "class example (String $value = ) { $other = \"value\" }\n"
      [[], ['--fix']].each do |options|
        File.write(file, code)
        output, _, status = cli(*options, file)
        refute status.success?
        assert_includes output, 'Invalid Puppet syntax'
        assert_includes output, ': syntax: error:'
        assert_equal code, File.read(file)
      end
    end
  end
end
