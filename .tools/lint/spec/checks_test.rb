require_relative 'test_helper'

class ChecksTest < Minitest::Test
  def findings(code, rule)
    lint = PuppetLint.new
    lint.path = 'example.pp'
    lint.code = code
    lint.run
    lint.problems.select { |problem| problem[:check].to_s == rule }
  end

  def test_nested_parameter_types_and_multiline_defaults
    code = <<~'PUPPET'
      class example (
        Array[Hash[String, Integer]] $items = [
          { 'example' => 1 },
        ],
        Optional[String]             $label = undef,
      ) {}
    PUPPET
    assert_empty findings(code, 'parameter_types')
    assert_empty findings(code, 'project_parameter_order')
    assert_empty findings(code, 'project_parameter_alignment')
    refute_empty findings('class example ($label = "demo") {}', 'parameter_types')
  end

  def test_optional_without_default_does_not_change_call_contract
    assert_empty findings('class example (String $z, Optional[String] $a) {}', 'project_parameter_order')
    refute_empty findings('class example (Optional[String] $a, String $z) {}', 'project_parameter_order')
    parsed = ProjectLint::Model.new('class example (String $z, Optional[String] $a) {}')
    assert_nil parsed.declarations.first.parameters.last.value
  end

  def test_interface_calls_require_optional_parameters_without_defaults
    definition = 'define example (Optional[String] $value) {}'
    refute_empty findings(definition + " example { 'synthetic': }", 'project_interface_calls')
    assert_empty findings(definition + " example { 'synthetic': value => undef }", 'project_interface_calls')
    assert_empty findings("define example (String $value = 'default') {} example { 'synthetic': }", 'project_interface_calls')
  end

  def test_default_dependencies_and_explanatory_comment
    code = <<~'PUPPET'
      class example (
        String $user = 'example', # Must precede $listen_user because its default reads this value.
        String $listen_user = $user,
      ) {}
    PUPPET
    assert_empty findings(code, 'project_parameter_order')
    refute_empty findings(code.sub(/ # Must[^\n]+/, ''), 'project_parameter_order')
    refute_empty findings('class example (String $listen_user = $user, String $user = "example") {}', 'project_parameter_order')
  end

  def test_alignment_including_mandatory_parameters
    valid = <<~'PUPPET'
      class example (
        String           $required,
        Optional[String] $optional = undef,
      ) {}
    PUPPET
    assert_empty findings(valid, 'project_parameter_alignment')
    refute_empty findings(valid.sub('String           $required', 'String $required'), 'project_parameter_alignment')
  end

  def test_documentation_matches_each_declaration
    valid = <<~'PUPPET'
      # @summary Demonstrates a documented interface.
      # @example Use the interface
      #   include example
      # @param label
      #   Name used for the example; defaults to demo.
      # @api public
      class example (String $label = 'demo') {}
    PUPPET
    assert_empty findings(valid, 'project_documentation')
    refute_empty findings(valid.sub('@param label', '@param other'), 'project_documentation')
    refute_empty findings(valid + "\nclass undocumented {}", 'project_documentation')
  end

  def test_only_approved_suppressions_are_allowed
    assert_empty findings('$x = "lint:ignore:140chars"', 'project_suppressions')
    assert_empty findings("# lint:ignore:140chars\n$x = 'demo'\n# lint:endignore", 'project_suppressions')
    source = "$source = 'puppet:///files/example/app.tar.gz'"
    assert_empty findings(source + ' # lint:ignore:puppet_url_without_modules', 'project_suppressions')
    %w[140chars puppet_url_without_modules].permutation.each do |checks|
      controls = checks.map { |check| "lint:ignore:#{check}" }.join(' ')
      assert_empty findings(source + " # #{controls}", 'project_suppressions')
    end
    refute_empty findings("$x = 'demo' # lint:ignore:double_quoted_strings", 'project_suppressions')
    refute_empty findings("$x = 'demo' # lint:ignore:140chars lint:ignore:project_arrays", 'project_suppressions')
    refute_empty findings(source + ' # lint:ignore:puppet_url_without_modules lint:ignore:project_puppet_urls', 'project_suppressions')
  end

  def test_puppet_url_ignore_is_local_and_keeps_the_additional_check_active
    source = "$source = 'puppet:///files/example/app.tar.gz'"
    annotated = source + ' # lint:ignore:puppet_url_without_modules'
    assert_equal [:ignored, :warning], findings(annotated + "\n" + source, 'puppet_url_without_modules').map { |problem| problem[:kind] }
    scoped = "# lint:ignore:puppet_url_without_modules\n#{source}\n# lint:endignore\n#{source}"
    assert_equal [:ignored, :warning], findings(scoped, 'puppet_url_without_modules').map { |problem| problem[:kind] }
    assert_empty findings(scoped, 'project_suppressions')
    assert_empty findings(annotated, 'project_puppet_urls')

    invalid = annotated.sub('/files/', '/invalid/')
    assert_equal [:ignored], findings(invalid, 'puppet_url_without_modules').map { |problem| problem[:kind] }
    assert_equal [:warning], findings(invalid, 'project_puppet_urls').map { |problem| problem[:kind] }
    assert_empty findings(invalid, 'project_suppressions')
  end

  def test_puppet_sources_accept_module_and_fileserver_mounts
    %w[modules files].each do |mount|
      ["puppet:///#{mount}/example/app.tar.gz", "puppet://puppet.example.org/#{mount}/example/app.tar.gz"].each do |source|
        assert_empty findings("$source = '#{source}'", 'project_puppet_urls')
        assert_empty findings("$source = \"#{source}\"", 'project_puppet_urls')
      end
      assert_empty findings(%($source = "puppet:///#{mount}/example/${filename}"), 'project_puppet_urls')
      assert_empty findings(%($source = "puppet:///#{mount}/${path}"), 'project_puppet_urls')
    end
    assert_empty findings("$sources = ['puppet:///modules/example/app.tar.gz', 'puppet:///files/example/app.tar.gz']", 'project_puppet_urls')
  end

  def test_puppet_sources_reject_unknown_missing_and_partial_mount_names
    %w[puppet:///invalid/example/app.tar.gz puppet:///files_backup/example/app.tar.gz puppet:///modules_extra/example/app.tar.gz puppet:///files puppet:///modules puppet:/// puppet://puppet.example.org puppet://puppet.example.org/invalid/app.tar.gz].each do |source|
      problems = findings("$source = '#{source}'", 'project_puppet_urls')
      assert_equal 1, problems.length, source
      assert_equal :warning, problems.first.fetch(:kind)
      assert_equal 1, problems.first.fetch(:line)
      assert_equal 11, problems.first.fetch(:column)
    end
    refute_empty findings('$source = "puppet:///invalid/${path}"', 'project_puppet_urls')
    problems = findings("$sources = ['puppet:///modules/example/app.tar.gz', 'puppet:///files/example/app.tar.gz', 'puppet:///invalid/example/app.tar.gz']", 'project_puppet_urls')
    assert_equal 1, problems.length
  end

  def test_puppet_source_check_keeps_other_schemes_and_prose_outside_its_scope
    assert_empty findings("$source = 'https://example.org/app.tar.gz'", 'project_puppet_urls')
    assert_empty findings("$source = 'file:///tmp/example/app.tar.gz'", 'project_puppet_urls')
    assert_empty findings("$message = 'Expected puppet:///modules/ or puppet:///files/'", 'project_puppet_urls')
    assert_empty findings("# puppet:///invalid/example/app.tar.gz\n", 'project_puppet_urls')
    refute_empty findings("$source = 'puppet:///invalid/example/app.tar.gz' # lint:ignore:project_puppet_urls", 'project_suppressions')
  end

  def test_line_length_suppression_does_not_hide_adjacent_lines_or_other_checks
    line = "$description = '#{'x' * 141}'"
    assert_equal :warning, findings(line, '140chars').first.fetch(:kind)
    annotated = line + " # lint:ignore:140chars\n" + line
    assert_equal [:ignored, :warning], findings(annotated, '140chars').map { |problem| problem[:kind] }
    assert_equal :warning, findings("$values = [1] + [2] # lint:ignore:140chars", 'project_arrays').first.fetch(:kind)
    comments = "# lint:ignore:140chars\n# #{'x' * 141}\n# lint:endignore\n" + line
    assert_equal [:ignored, :warning], findings(comments, '140chars').map { |problem| problem[:kind] }
  end

  def test_line_length_control_comments_preserve_documentation_validation
    valid = <<~'PUPPET'
      # lint:ignore:140chars
      # @summary Demonstrates a documented interface with a long explanation.
      # lint:endignore
      # @example Use the interface
      #   include example
      # @param label
      # lint:ignore:140chars
      #   Name used for the example; defaults to demo.
      # lint:endignore
      # @api public
      class example (String $label = 'demo') {}
    PUPPET
    assert_empty findings(valid, 'project_documentation')
    refute_empty findings(valid.sub('@param label', '@param other'), 'project_documentation')
  end

  def test_package_removal_and_non_apt_provider
    assert_empty findings("package { 'demo': ensure => purged }", 'project_packages')
    assert_empty findings("package { 'demo': provider => gem }", 'project_packages')
    refute_empty findings("package { 'demo': ensure => installed }", 'project_packages')
    valid = "package { 'demo': install_options => ['--no-install-recommends', '--no-install-suggests'] }"
    assert_empty findings(valid, 'project_packages')
  end

  def test_resource_defaults_apply_to_files_and_packages
    assert_empty findings("File { owner => 'root', group => 'root', mode => '0600' } file { '/tmp/example': ensure => file }", 'project_files')
    assert_empty findings("Package { install_options => ['--no-install-recommends', '--no-install-suggests'] } package { 'demo': ensure => installed }", 'project_packages')
    refute_empty findings("file { '/tmp/example': ensure => file }", 'project_files')
    assert_empty findings("file { '/tmp/example': ensure => absent }", 'project_files')
    assert_empty findings("file { '/tmp/example': ensure => link, target => '/tmp/target', owner => 'root', group => 'root' }", 'project_files')
    assert_empty findings("package { 'demo': install_options => concat($options, ['--no-install-recommends', '--no-install-suggests']) }", 'project_packages')
    refute_empty findings("package { 'demo': install_options => union($options, ['--no-install-recommends', '--no-install-suggests']) }", 'project_packages')
    refute_empty findings("package { 'demo': install_options => ['--no-install-recommends', '--no-install-suggests', '--install-recommends'] }", 'project_packages')
  end

  def test_source_content_exclusion_requires_a_real_guard
    code = <<~'PUPPET'
      class example (Optional[String] $content = undef, Optional[String] $source = undef) {
        if $source == undef or $content == undef {
          file { '/tmp/example': source => $source, content => $content, owner => 'root', group => 'root', mode => '0600' }
        } else { fail('Choose one input') }
      }
    PUPPET
    assert_empty findings(code, 'project_files')
    refute_empty findings(code.sub('$source == undef or $content == undef', '$source != undef or $content != undef'), 'project_files')
    derived = <<~'PUPPET'
      class example (Optional[String] $content = undef, Optional[String] $source = undef) {
        if $source == undef { $resolved = $content } else { $resolved = undef }
        file { '/tmp/example': source => $source, content => $resolved, owner => 'root', group => 'root', mode => '0600' }
      }
    PUPPET
    assert_empty findings(derived, 'project_files')
    refute_empty findings(derived.sub('$resolved = undef', '$resolved = $content'), 'project_files')
  end

  def test_numeric_and_hash_addition_remain_valid
    assert_empty findings('$x = 1 + 2', 'project_arrays')
    assert_empty findings("$x = { 'a' => 1 } + { 'b' => 2 }", 'project_arrays')
    refute_empty findings('$x = [1] + [2]', 'project_arrays')
    refute_empty findings('class example (Array[String] $items) { $all = $items + ["demo"] }', 'project_arrays')
    assert_empty findings('$x = concat([1], [2])', 'project_arrays')
    assert_empty findings('class array_scope (Array $items) {} class number_scope (Integer $items) { $result = $items + 1 }', 'project_arrays')
  end

  def test_inheritance_and_overrides_require_catalog_review
    inherited = "class parent { File { owner => 'root', group => 'root', mode => '0600' } } class example inherits parent { file { '/tmp/example': } }"
    result = findings(inherited, 'project_files')
    assert_equal 1, result.length
    assert result.first[:message].start_with?('[review]')
    overridden = "file { '/tmp/example': } File['/tmp/example'] { owner => 'root', group => 'root', mode => '0600' }"
    assert findings(overridden, 'project_files').all? { |finding| finding[:message].start_with?('[review]') }
    nested = "if true { File { owner => 'root', group => 'root', mode => '0600' } } file { '/tmp/example': }"
    refute_empty findings(nested, 'project_files')
  end

  def test_template_function_not_string_or_comment
    assert_empty findings("$x = template('example/config') # epp('example/config')", 'project_templates')
    assert_empty findings('$x = "epp(\'example/config\')"', 'project_templates')
    refute_empty findings("$x = epp('example/config.epp')", 'project_templates')
  end

  def test_heredoc_content_is_not_puppet_code
    code = <<~'PUPPET'
      $text = @(END)
      epp('demo.epp')
      $a = [1] + [2]
      # lint:ignore:140chars
      END
    PUPPET
    %w[project_templates project_arrays project_suppressions].each { |rule| assert_empty findings(code, rule) }
  end

  def test_shell_values_need_real_escaping_provenance
    safe = <<~'PUPPET'
      class example (String $argument) {
        $argument_shell = stdlib::shell_escape($argument)
        $script = "/usr/bin/printf %s ${argument_shell}"
        exec { 'demo': command => $script }
      }
    PUPPET
    assert_empty findings(safe, 'project_shell')
    refute_empty findings(safe.sub('stdlib::shell_escape($argument)', '$argument'), 'project_shell')
    assert_empty findings(%q(exec { 'demo': command => '/bin/sh -c "printf %s \"$1\""' }), 'project_shell')
    assert_empty findings(safe.sub('command => $script', 'command => Sensitive.new($script)'), 'project_shell')
  end

  def test_shell_scope_and_multiple_assignments
    code = <<~'PUPPET'
      class example (String $argument) {
        if $argument == 'example' {
          $argument_shell = stdlib::shell_escape($argument)
        } else {
          $argument_shell = $argument
        }
        exec { 'demo': command => "/bin/echo ${argument_shell}" }
      }
    PUPPET
    refute_empty findings(code, 'project_shell')
    mapped = <<~'PUPPET'
      class example (Array[String] $arguments) {
        $words_shell = $arguments.map |$argument| { stdlib::shell_escape($argument) }
        $command = join(['/bin/echo', join($words_shell, ' ')], ' ')
        exec { 'demo': command => $command }
      }
    PUPPET
    assert_empty findings(mapped, 'project_shell')
    refute_empty findings(mapped.sub('stdlib::shell_escape($argument)', '$argument'), 'project_shell')
    assigned = mapped.sub('stdlib::shell_escape($argument) }', '$argument_shell = stdlib::shell_escape($argument); $argument_shell }')
    assert_empty findings(assigned, 'project_shell')
    refute_empty findings(assigned.sub('stdlib::shell_escape($argument)', '$argument'), 'project_shell')
  end

  def test_layout_handles_strings_comments_and_nested_types
    assert_empty findings("class example (\n  Enum['a', 'b'] $label = 'comma,inside',\n) {}", 'project_layout')
    refute_empty findings("class example (\n  Enum['a','b'] $label = 'comma,inside'\n) {}", 'project_layout')
  end

  def test_layout_rejects_blank_lines_after_opening_braces_in_nested_blocks
    code = <<~'PUPPET'
      # Check whether this service runs a Node.js application.
      if ('ExecStart' in $service and $service['ExecStart'] =~ String and $service['ExecStart'] =~ /^(?:node|\.{1,2}\/node|\/(?:[^\/\s]+\/)+node)\s+/) { # lint:ignore:140chars

        # Require a working directory for the dependency audit.
        if ('WorkingDirectory' in $service and $service['WorkingDirectory'] =~ String) {

          basic_settings::monitoring_npm_audit { 'synthetic':
            dir => $service['WorkingDirectory'],
          }
        }
      }
    PUPPET
    problems = findings(code, 'project_layout')
    assert_equal [3, 6], problems.map { |problem| problem.fetch(:line) }
    assert problems.all? { |problem| problem[:kind] == :warning && problem[:column] == 1 }
    assert problems.all? { |problem| problem[:message] == 'Remove blank lines immediately after an opening brace' }

    corrected = code.gsub("\n\n", "\n")
    %w[project_layout project_comment_spacing project_if_sections].each do |rule|
      assert_empty findings(corrected, rule)
    end
  end

  def test_layout_checks_braces_in_declarations_collections_and_control_flow
    wrappers = [
      ["class example {", "}"],
      ["define example {", "}"],
      ["if $active {", "}"],
      ["unless $active {", "}"],
      ["if $active {} else {", "}"],
      ["if $active {} elsif $fallback {", "}"],
      ["case $state {", "  default: {}\n}"],
      ["case $state { default: {", "} }"],
      ["[1].each |$value| {", "}"],
      ["$values = {", "  'key' => 'value',\n}"],
      ["$value = $active ? {", "  default => undef,\n}"],
      ["notify {", "  'synthetic':\n}"],
    ]
    wrappers.each do |opening, closing|
      code = "#{opening}\n\n#{closing}\n"
      assert_equal [2], findings(code, 'project_layout').map { |problem| problem.fetch(:line) }, opening
      assert_empty findings(code.sub("\n\n", "\n"), 'project_layout'), opening
    end
  end

  def test_layout_reports_the_first_blank_line_including_whitespace_and_inline_comments
    ['', ' # Explain the body.', ' # lint:ignore:140chars', ' /* Explain the body. */'].each do |suffix|
      ["\n\n", "\n \t\n\n", "\r\n \t\r\n\r\n"].each do |spacing|
        code = "if $active {#{suffix}#{spacing}  notice('Active')\n}\n"
        assert_equal [2], findings(code, 'project_layout').map { |problem| problem.fetch(:line) }, code
      end
    end
  end

  def test_layout_preserves_content_and_spacing_elsewhere_in_blocks
    sources = [
      "if $active {}\n",
      "if $active {\n}\n",
      "if $active { notice('Active')\n\n  notice('Ready')\n}\n",
      "if $active {\n  notice('Active')\n\n  # Explain the next operation.\n  notice('Ready')\n\n}\n",
      "if $active {\n  # Explain the operation.\n\n  notice('Ready')\n}\n",
      "# A literal {\n\nnotice('Ready')\n",
      "/* A literal {\n\n*/\nnotice('Ready')\n",
      "$text = '{\n\n}'\n",
      "$text = \"{\n\n${value}\"\n",
      "$pattern = /{\n\n}/\n",
      "if $active { /* Explain this block.\n\n  More explanation. */\n  notice('Active')\n}\n",
      "if $active { notice('{\n\n}')\n}\n",
      "$values = [\n\n  1,\n]\n",
      "notice(\n\n  'Ready',\n)\n",
      <<~'PUPPET',
        $text = @(CONTENT)
        {

        literal content
        CONTENT
      PUPPET
    ]
    sources.each { |code| assert_empty findings(code, 'project_layout'), code }
  end

  def test_comment_spacing_between_assignments
    code = <<~'PUPPET'
      $config_file_shell = stdlib::shell_escape($config_file)
      # Normalize whitespace before constructing the registration command.
      $server_name_correct = regsubst($server_name, '\s+', ' ', 'G')
    PUPPET
    problems = findings(code, 'project_comment_spacing')
    assert_equal [[2, 1]], problems.map { |problem| problem.values_at(:line, :column) }
    assert_empty findings(code.sub("\n#", "\n\n#"), 'project_comment_spacing')
    assert_empty findings(code.sub("\n#", "\n \t\n#"), 'project_comment_spacing')
  end

  def test_comment_spacing_preserves_opening_blocks_and_contiguous_comments
    code = <<~'PUPPET'
      # File-level explanation.
      # The next line continues the same explanation.
      class example (
        # This value selects the synthetic instance.
        String $name = 'demo',
      ) {
        # Keep this first section inside the class.
        $items = [
          # The first item needs no leading blank line.
          'demo',
        ]
      }
    PUPPET
    assert_empty findings(code, 'project_comment_spacing')
    refute_empty findings("$first = 1 # Explain the first value.\n# Explain the next value.\n$second = 2\n", 'project_comment_spacing')
  end

  def test_comment_spacing_uses_lexer_comments_not_string_contents
    code = <<~'PUPPET'
      $message = 'First line.
      # This is literal text.
      Last line.'
      $other = "A # sign in a string" # Trailing explanation.
      $payload = @(TEXT)
        }
        # This is heredoc content.
        notify { 'literal': }
        | TEXT
    PUPPET
    assert_empty findings(code, 'project_comment_spacing')
    assert_empty findings(code, 'project_resource_sections')
  end

  def test_comment_spacing_handles_block_comments_and_lint_metadata
    code = "$value = 1\n/* Explain the next section.\n * Preserve this continuation. */\n$other = 2\n"
    assert_equal [2], findings(code, 'project_comment_spacing').map { |problem| problem[:line] }
    assert_empty findings(code.sub("\n/*", "\n\n/*"), 'project_comment_spacing')
    assert_empty findings("$value = 1\n# lint:ignore:140chars\n$other = 2\n# lint:endignore\n", 'project_comment_spacing')
    wrapped = "$value = 1\n# lint:ignore:140chars\n# Explain the next value.\n# lint:endignore\n$other = 2\n"
    assert_equal [2], findings(wrapped, 'project_comment_spacing').map { |problem| problem[:line] }
    assert_empty findings(wrapped.sub("\n# lint:ignore", "\n\n# lint:ignore"), 'project_comment_spacing')
    closed = "# lint:ignore:140chars\n$value = 1\n# lint:endignore\n# Explain the next value.\n$other = 2\n"
    assert_equal [4], findings(closed, 'project_comment_spacing').map { |problem| problem[:line] }
    assert_empty findings(closed.sub("# lint:endignore\n", "# lint:endignore\n\n"), 'project_comment_spacing')
  end

  def test_resource_sections_after_conditions_need_their_own_explanation
    code = <<~'PUPPET'
      if $active {
        $message = 'active'
      } else {
        $message = 'inactive'
      }
      notify { 'state': message => $message }
    PUPPET
    assert_equal [[6, 1]], findings(code, 'project_resource_sections').map { |problem| problem.values_at(:line, :column) }
    refute_empty findings(code.sub("\nnotify", "\n\nnotify"), 'project_resource_sections')
    corrected = code.sub("\nnotify", "\n\n# Report the selected state.\nnotify")
    assert_empty findings(corrected, 'project_resource_sections')
    assert_empty findings(corrected, 'project_comment_spacing')
    unseparated = code.sub("\nnotify", "\n# Report the selected state.\nnotify")
    assert_empty findings(unseparated, 'project_resource_sections')
    refute_empty findings(unseparated, 'project_comment_spacing')
  end

  def test_resource_sections_cover_defined_types_defaults_overrides_and_virtual_resources
    declarations = [
      "basic_settings::monitoring_custom { 'example': }",
      "Notify { message => 'default' }",
      "Notify['example'] { message => 'override' }",
      "@notify { 'example': }",
      "@@notify { 'example': }",
      "class { 'example': }",
    ]
    declarations.each do |declaration|
      code = "if $active { $value = 1 }\n#{declaration}\n"
      assert_equal [:warning], findings(code, 'project_resource_sections').map { |problem| problem[:kind] }, declaration
      assert_empty findings(code.sub("\n", "\n\n# Register the selected instance.\n"), 'project_resource_sections'), declaration
    end
  end

  def test_resource_sections_recognize_closed_expressions_and_same_line_resources
    preceding = [
      "notify { 'first': }",
      "$options = { 'message' => 'example' }",
      "$message = $active ? { true => 'yes', default => 'no' }",
      "$items = ['one'].map |$item| { $item }",
      "case $active { default: { $message = 'example' } }",
    ]
    preceding.each do |statement|
      ["\n", ' ', ";\n"].each do |separator|
        code = statement + separator + "notify { 'second': }\n"
        assert_equal [:warning], findings(code, 'project_resource_sections').map { |problem| problem[:kind] }, code
      end
    end
  end

  def test_resource_sections_do_not_split_relationship_chains_or_opening_blocks
    %w[-> ~> <- <~].each do |relationship|
      assert_empty findings("notify { 'first': } #{relationship}\nnotify { 'second': }\n", 'project_resource_sections')
    end
    assert_empty findings("if $active {\n  notify { 'example': }\n}\n", 'project_resource_sections')
    assert_empty findings("$message = '} # literal'\nnotify { 'example': }\n", 'project_resource_sections')
    assert_empty findings("$options = [1, 2]\nnotify { 'example': }\n", 'project_resource_sections')
  end

  def test_section_positions_handle_crlf_and_multibyte_text
    code = "notify { 'café': } notify { 'next': }\r\n# Explain the next value.\r\n$value = 1\r\n"
    assert_equal [:warning], findings(code, 'project_resource_sections').map { |problem| problem[:kind] }
    assert_equal [2], findings(code, 'project_comment_spacing').map { |problem| problem[:line] }
  end

  def test_resource_sections_reject_empty_trailing_and_control_only_comments
    ["#\n", "# lint:ignore:140chars\n# lint:endignore\n", "# Explain the previous block.\n\n"].each do |comment|
      refute_empty findings("if $active { $value = 1 }\n\n#{comment}notify { 'example': }\n", 'project_resource_sections')
    end
    refute_empty findings("if $active { $value = 1 } # Explain this condition.\nnotify { 'example': }\n", 'project_resource_sections')
    code = "if $active { $value = 1 }\n\n# lint:ignore:140chars\n# Report the selected state.\n# lint:endignore\nnotify { 'example': }\n"
    assert_empty findings(code, 'project_resource_sections')
    assert_empty findings(code, 'project_comment_spacing')
  end

  def test_variable_sections_split_the_name_group_before_independent_check_settings
    code = <<~'PUPPET'
      # Normalize names for the command and its label.
      $server_name_correct = regsubst($server_name ? { undef => '', default => $server_name }, '\s+', ' ', 'G')
      $server_name_shell = stdlib::shell_escape($server_name_correct)
      $check_friendly = "Nginx TLS ${server_name_correct}"
      $detail_limit_shell = stdlib::shell_escape(String($detail_limit))
      $timeout_shell = stdlib::shell_escape(String($timeout))
      $validity_critical_shell = stdlib::shell_escape(String($validity_critical))
      $validity_warning_shell = stdlib::shell_escape(String($validity_warning))
      $command = "${server_name_shell} ${detail_limit_shell} ${timeout_shell} ${validity_critical_shell} ${validity_warning_shell}"
    PUPPET
    assert_equal [[5, 1]], findings(code, 'project_variable_sections').map { |problem| problem.values_at(:line, :column) }
    corrected = code.sub("\n$detail_limit_shell", "\n\n# Escape the numeric check settings.\n$detail_limit_shell")
    assert_empty findings(corrected, 'project_variable_sections')
    assert_empty findings(corrected, 'project_comment_spacing')
  end

  def test_variable_sections_need_an_explanation_and_reuse_comment_spacing
    code = "# Prepare the value.\n$value = 'example'\n$label = $value\n$timeout = 30\n"
    ["\n", "\n\n", " # Explain the label.\n", "\n\n#\n", "\n# lint:ignore:140chars\n# lint:endignore\n"].each do |separator|
      changed = code.sub("\n$timeout", "#{separator}$timeout")
      assert_equal [:warning], findings(changed, 'project_variable_sections').map { |problem| problem[:kind] }, changed
    end
    unseparated = code.sub("\n$timeout", "\n# Set the timeout.\n$timeout")
    assert_empty findings(unseparated, 'project_variable_sections')
    assert_equal [:warning], findings(unseparated, 'project_comment_spacing').map { |problem| problem[:kind] }
  end

  def test_variable_sections_allow_batches_without_proven_internal_dependencies
    code = <<~'PUPPET'
      # Escape the independent settings for the command.
      $detail_shell = stdlib::shell_escape(String($detail))
      $timeout_shell = stdlib::shell_escape(String($timeout))
      $warning_shell = stdlib::shell_escape(String($warning))
      $critical_shell = stdlib::shell_escape(String($critical))
    PUPPET
    assert_empty findings(code, 'project_variable_sections')
    assert_empty findings("# Set independent defaults.\n$timeout = 30\n$owner = 'root'\n$enabled = true\n", 'project_variable_sections')
    assert_empty findings("# Read the existing input.\n$first = $input\n$second = $input\n$timeout = 30\n", 'project_variable_sections')
  end

  def test_variable_sections_follow_transitive_reads_and_report_once_per_boundary
    code = <<~'PUPPET'
      # Prepare the first group.
      $first = 'one'
      $second = $first
      $third = "${second} label"
      $timeout = 30
      $limit = 60
      $limit_shell = stdlib::shell_escape(String($limit))
      $owner = 'root'
      $group = 'root'
    PUPPET
    assert_equal [5, 8], findings(code, 'project_variable_sections').map { |problem| problem[:line] }
  end

  def test_variable_sections_do_not_guess_from_names_comments_or_literal_text
    code = <<~'PUPPET'
      # Literal $seed text does not create a dependency.
      $seed = 'example'
      $label = 'Literal ${seed} text'
      $seed_timeout = 30
    PUPPET
    assert_empty findings(code, 'project_variable_sections')
    interpolated = code.sub("'Literal ${seed} text'", '"Literal ${seed} text"')
    assert_equal [4], findings(interpolated, 'project_variable_sections').map { |problem| problem[:line] }
    renamed = interpolated.gsub('seed_timeout', 'unrelated').gsub('seed', 'input')
    assert_equal [4], findings(renamed, 'project_variable_sections').map { |problem| problem[:line] }
  end

  def test_variable_sections_limit_dependency_grouping_to_annotated_sequences
    assert_empty findings("$first = 'one'\n$second = $first\n$timeout = 30\n", 'project_variable_sections')
    code = "# Prepare the label.\n$first = 'one'\n$second = $first\nnotice('done')\n$timeout = 30\n"
    assert_empty findings(code, 'project_variable_sections')
    code = "# Prepare the label.\n$first = 'one'\n$second = $first\nif $active { $timeout = 30; $limit = 60 }\n"
    assert_equal [4], findings(code, 'project_variable_sections').map { |problem| problem[:line] }
    assert_equal [2], findings("# Explain the condition.\nif $active { $first = 'one'; $second = $first; $timeout = 30 }\n", 'project_variable_sections').map { |problem| problem[:line] }
  end

  def test_variable_sections_check_nested_blocks_without_leaking_state
    code = <<~'PUPPET'
      if $active {
        # Prepare the label inside this branch.
        $first = 'one'
        $second = $first
        $timeout = 30
      } else {
        $timeout = 60
      }
      $result = $items.map |$item| {
        # Prepare the label inside this lambda.
        $first = $item
        $second = $first
        $limit = 100
        $second
      }
    PUPPET
    assert_equal [[5, 3], [7, 3], [13, 3]], findings(code, 'project_variable_sections').map { |problem| problem.values_at(:line, :column) }.sort
  end

  def test_variable_sections_respect_lambda_parameters_and_local_assignments
    code = "# Prepare mapped values.\n$seed = 'outer'\n$result = [1].map |$item| { $seed }\n$timeout = 30\n"
    assert_equal [4], findings(code, 'project_variable_sections').map { |problem| problem[:line] }
    assert_empty findings(code.sub('|$item|', '|$seed|'), 'project_variable_sections')
    assert_empty findings(code.sub('{ $seed }', "{\n# Keep this seed local to each iteration.\n$seed = 'inner'; $seed }"), 'project_variable_sections')
    nested = code.sub('{ $seed }', '{ [2].map |$seed| { $seed } }')
    assert_empty findings(nested, 'project_variable_sections')
  end

  def test_variable_sections_support_destructuring_and_multiline_expressions
    code = <<~'PUPPET'
      # Prepare the selected values.
      [$first, $second] = ['one', 'two']
      $label = join([
        # This comment describes an array element, not a new assignment section.
        $first,
        $second,
      ], ' ')
      $timeout = 30
    PUPPET
    assert_equal [8], findings(code, 'project_variable_sections').map { |problem| problem[:line] }
  end

  def test_variable_sections_handle_block_comments_crlf_and_same_line_assignments
    code = "/* Prepare a café label. */\n$first = 'café'; $second = $first; $timeout = 30\n"
    assert_equal [:warning], findings(code, 'project_variable_sections').map { |problem| problem[:kind] }
    assert_equal [:warning], findings(code.gsub("\n", "\r\n"), 'project_variable_sections').map { |problem| problem[:kind] }
    wrapped = "# lint:ignore:140chars\n# Prepare a label.\n# lint:endignore\n$first = 'one'\n$second = $first\n$timeout = 30\n"
    assert_equal [6], findings(wrapped, 'project_variable_sections').map { |problem| problem[:line] }
  end

  def test_variable_sections_explain_assignments_at_each_block_opening
    code = <<~'PUPPET'
      # Select the active state.
      if $active {
        $value = 'active'
      } elsif $pending {
        $value = 'pending'
      } else {
        $value = 'inactive'
      }
    PUPPET
    assert_equal [3, 5, 7], findings(code, 'project_variable_sections').map { |problem| problem[:line] }
    corrected = code.gsub("  $value", "  # Prepare the label for this state.\n  $value")
    assert_empty findings(corrected, 'project_variable_sections')
  end

  def test_variable_sections_cover_classes_defines_case_arms_and_lambdas
    sources = [
      "class example { $value = 'example' }",
      "define example { $value = 'example' }",
      "case $state { default: { $value = 'example' } }",
      "$items.each |$item| { $value = $item }",
      "unless $active { [$one, $two] = [1, 2] }",
    ]
    sources.each do |code|
      assert_equal [:warning], findings(code, 'project_variable_sections').map { |problem| problem[:kind] }, code
    end
    assert_empty findings("$value = 'example'", 'project_variable_sections')
    assert_empty findings("if $active { notice('Active'); $value = 'example' }", 'project_variable_sections')
    assert_empty findings("$values = { 'first' => 1 }", 'project_variable_sections')
    assert_empty findings("$literal = 'if $active { $value = 1 }'", 'project_variable_sections')
  end

  def test_variable_sections_require_real_internal_comments_without_a_leading_blank_line
    ["", "\n", "#\n", "# lint:ignore:140chars\n# lint:endignore\n"].each do |prefix|
      code = "# Explain the condition.\nif $active {\n#{prefix}  $value = 'example'\n}\n"
      assert_equal [:warning], findings(code, 'project_variable_sections').map { |problem| problem[:kind] }, prefix
    end
    ['# Prepare the local label.', '/* Prepare the local label. */'].each do |comment|
      code = "# Explain the condition.\nif $active {\n  #{comment}\n  $value = 'café'\n}\n"
      assert_empty findings(code, 'project_variable_sections')
      assert_empty findings(code, 'project_comment_spacing')
      assert_empty findings(code.gsub("\n", "\r\n"), 'project_variable_sections')
    end
  end

  def test_variable_sections_hint_at_a_later_documented_group_with_the_same_function
    code = <<~'PUPPET'
      if $active {
        $config_shell = stdlib::shell_escape($config)

        # Prepare a related name and label.
        $name = regsubst($input, '\s+', ' ', 'G')
        $name_shell = stdlib::shell_escape($name)
        $label = "Check ${name}"

        # Escape the remaining check settings.
        $timeout_shell = stdlib::shell_escape(String($timeout))
        $command = "${config_shell} ${name_shell} ${timeout_shell}"
      }
    PUPPET
    problems = findings(code, 'project_variable_sections')
    assert_equal [2], problems.map { |problem| problem[:line] }
    assert_includes problems.first[:message], 'section at line 9'
    assert_includes problems.first[:message], 'checking purpose and evaluation order'
    renamed = code.gsub('stdlib::shell_escape', 'example::transform')
    assert_includes findings(renamed, 'project_variable_sections').first[:message], 'section at line 9'
  end

  def test_variable_sections_do_not_suggest_moving_past_a_use_or_control_boundary
    ['notice($config_shell)', '$used = $config_shell', "if $other { notice('Other') }"].each do |intervening|
      code = "if $active {\n$config_shell = stdlib::shell_escape($config)\n#{intervening}\n\n# Escape the timeout.\n$timeout_shell = stdlib::shell_escape(String($timeout))\n}\n"
      problems = findings(code, 'project_variable_sections')
      assert_equal [2], problems.map { |problem| problem[:line] }
      refute_includes problems.first[:message], 'section at line'
    end
    code = "if $active {\n$config_shell = stdlib::shell_escape($config)\n} else {\n# Escape the timeout.\n$timeout_shell = stdlib::shell_escape(String($timeout))\n}\n"
    refute_includes findings(code, 'project_variable_sections').first[:message], 'section at line'
    different = "if $active {\n$config_shell = stdlib::shell_escape($config)\n# Format the timeout.\n$timeout_label = String($timeout)\n}\n"
    refute_includes findings(different, 'project_variable_sections').first[:message], 'section at line'

    # Calls that own lambdas are not simple transformations to regroup.
    matching = different.sub('String($timeout)', 'stdlib::shell_escape($timeout)')
    ['stdlib::shell_escape($config)', 'stdlib::shell_escape($timeout)'].each do |call|
      with_lambda = matching.sub(call, "#{call} |$item| { $item }")
      refute_includes findings(with_lambda, 'project_variable_sections').first[:message], 'section at line'
    end
  end

  def test_if_sections_require_an_explanation_for_standalone_conditions
    code = "if (defined(Class['nginx'])) { notice('Available') }\n"
    assert_equal [[1, 1]], findings(code, 'project_if_sections').map { |problem| problem.values_at(:line, :column) }
    assert_empty findings("# Require the parent before configuring its resources.\n#{code}", 'project_if_sections')
    assert_empty findings("# Require the parent before configuring its resources.\n\n#{code}", 'project_if_sections')
  end

  def test_if_sections_place_the_explanation_above_transitive_condition_inputs
    code = <<~'PUPPET'
      $monitoring_enable = defined(Class['basic_settings::monitoring'])
      $active = $ensure == present and $monitoring_enable and $basic_settings::monitoring::package != 'none'
      if (!$active or ($validity_critical < $validity_warning and $config_file !~ /[\r\n\t]/)) {
        notice('Valid registration settings')
      }
    PUPPET
    assert_equal [[1, 1]], findings(code, 'project_if_sections').map { |problem| problem.values_at(:line, :column) }
    assert_empty findings("# Validate registration settings only when this backend is active.\n#{code}", 'project_if_sections')
    misplaced = code.sub('if (', "# Validate the registration.\nif (")
    assert_equal [1], findings(misplaced, 'project_if_sections').map { |problem| problem[:line] }
  end

  def test_if_sections_follow_multiple_condition_inputs_and_destructuring
    code = "[$minimum, $maximum] = [1, 10]\n$valid = $minimum < $maximum\nif $valid { notice('Valid') }\n"
    assert_equal [1], findings(code, 'project_if_sections').map { |problem| problem[:line] }
    assert_empty findings("# Validate the allowed range before using it.\n#{code}", 'project_if_sections')
    separate = "$minimum = 1\n$maximum = 10\nif $minimum < $maximum { notice('Valid') }\n"
    assert_equal [1], findings(separate, 'project_if_sections').map { |problem| problem[:line] }
  end

  def test_if_sections_do_not_reuse_comments_across_unrelated_work
    prefix = "# Derive the active state.\n$first = true\n$active = $first\n"
    ["$unrelated = 30\n", "notice('Preparation finished')\n", "notify { 'ready': }\n"].each do |separator|
      code = prefix + separator + "if $active { notice('Active') }\n"
      assert_equal [5], findings(code, 'project_if_sections').map { |problem| problem[:line] }, separator
      assert_empty findings(code.sub('if $active', "# Perform the active operation.\nif $active"), 'project_if_sections')
    end
  end

  def test_if_sections_do_not_reuse_a_parent_or_previous_condition_explanation
    code = <<~'PUPPET'
      # Check the outer prerequisite.
      if $outer {
        if $inner { notice('Nested') }
      } else {
        if $fallback { notice('Fallback') }
      }
      if $other { notice('Other') }
    PUPPET
    assert_equal [3, 5, 7], findings(code, 'project_if_sections').map { |problem| problem[:line] }
    assert_equal [2], findings("# Explain the class.\nclass example { if $active { notice('Active') } }", 'project_if_sections').map { |problem| problem[:line] }
  end

  def test_if_sections_keep_elsif_in_the_same_chain_and_cover_unless
    code = "# Select the first applicable mode.\nif $first { notice('First') } elsif $second { notice('Second') } else { notice('Fallback') }\n"
    assert_empty findings(code, 'project_if_sections')
    assert_equal [:warning], findings(code.lines.drop(1).join, 'project_if_sections').map { |problem| problem[:kind] }
    assert_equal [:warning], findings("unless $active { notice('Disabled') }", 'project_if_sections').map { |problem| problem[:kind] }
    assert_empty findings("# Report disabled operation.\nunless $active { notice('Disabled') }", 'project_if_sections')
    prepared = "# Select the first available owner.\n$first = true\n$second = false\nif $first { notice('First') } elsif $second { notice('Second') }\n"
    assert_empty findings(prepared, 'project_if_sections')
  end

  def test_if_sections_require_real_comments_and_reuse_existing_spacing
    body = "if $active { notice('Active') }\n"
    ["#\n", "# lint:ignore:140chars\n# lint:endignore\n", "$label = '# A literal comment'\n", "$label = 'label' # Trailing comment.\n"].each do |prefix|
      assert_equal [:warning], findings(prefix + body, 'project_if_sections').map { |problem| problem[:kind] }, prefix
    end
    assert_empty findings("/* Explain the selected operation. */\n#{body}", 'project_if_sections')
    assert_empty findings("# lint:ignore:140chars\n# Explain the operation.\n# lint:endignore\n#{body}", 'project_if_sections')
    code = "$label = 'label'\n# Explain the operation.\n#{body}"
    assert_empty findings(code, 'project_if_sections')
    assert_equal [:warning], findings(code, 'project_comment_spacing').map { |problem| problem[:kind] }
  end

  def test_if_sections_respect_lambda_scope_in_condition_dependencies
    code = "# Prepare the outer value.\n$active = true\nif [true].any |$active| { $active } { notice('Active') }\n"
    assert_equal [3], findings(code, 'project_if_sections').map { |problem| problem[:line] }
    assert_empty findings(code.sub('|$active|', '|$item|'), 'project_if_sections')
  end

  def test_if_sections_accept_an_explanation_above_an_assigned_if_expression
    code = "$label = if $active { 'active' } else { 'inactive' }\n"
    assert_equal [[1, 1]], findings(code, 'project_if_sections').map { |problem| problem.values_at(:line, :column) }
    assert_empty findings("# Select the label for the current state.\n#{code}", 'project_if_sections')
  end

  def test_if_sections_handle_multiline_conditions_crlf_and_literal_if_text
    code = "# Check the café label.\n$label = 'café'\nif (\n  $label != ''\n) { notice($label) }\n"
    assert_empty findings(code, 'project_if_sections')
    assert_empty findings(code.gsub("\n", "\r\n"), 'project_if_sections')
    assert_empty findings("$label = 'if $active { # literal }'", 'project_if_sections')
  end

  def test_positive_flow_keeps_guards_without_else_and_equally_small_branches
    assert_empty findings("if !defined(Package['example']) { package { 'example': } }", 'project_positive_flow')
    assert_empty findings("if $active { $value = 'first' } else { $value = 'second' }", 'project_positive_flow')
    assert_empty findings("if defined(Class['example']) { file { '/tmp/example': } } else { fail('Missing parent') }", 'project_positive_flow')
  end

  def test_positive_flow_rejects_short_assignments_before_the_larger_else
    code = <<~'PUPPET'
      if $absent {
        $content = undef
        $dependencies = undef
      } else {
        $content = template('example/check')
        $dependencies = [Package['example']]
        $owner = 'root'
        $mode = '0700'
      }
    PUPPET
    assert_equal [[1, :warning]], findings(code, 'project_positive_flow').map { |problem| problem.values_at(:line, :kind) }
    reversed = "if !$absent { $content = 'text'; $dependencies = []; $owner = 'root'; $mode = '0700' } else { $content = undef; $dependencies = undef }"
    assert_empty findings(reversed, 'project_positive_flow')
  end

  def test_positive_flow_handles_all_short_calls_through_the_same_structure_rule
    %w[fail warning notice custom::report_issue].each do |function|
      code = "if $missing { #{function}('Synthetic message') } else { file { '/tmp/example': } }"
      problems = findings(code, 'project_positive_flow')
      assert_equal [:warning], problems.map { |problem| problem[:kind] }, function
      assert_equal problems.first[:message], findings(code.sub(function, 'notice'), 'project_positive_flow').first[:message]
    end
    code = "if $missing { warning('First'); fail('Second') } else { $one = 1; $two = 2; $three = 3 }"
    assert_equal [:warning], findings(code, 'project_positive_flow').map { |problem| problem[:kind] }
  end

  def test_positive_flow_counts_nested_work_inside_single_top_level_statements
    bodies = [
      "if $nested { $one = 1; $two = 2 } else { $one = 0 }",
      "case $kind { 'one': { $value = 1 } default: { $value = 2 } }",
      "$values = ['one'].map |$value| { $first = $value; $second = $value; $second }",
      "file { '/tmp/first': ensure => absent; '/tmp/second': ensure => absent }",
      "File { owner => 'root', group => 'root', mode => '0600' }",
      "File['/tmp/example'] { owner => 'root', group => 'root', mode => '0600' }",
    ]
    bodies.each do |body|
      code = "if $absent { $one = undef; $two = undef } else { #{body} }"
      assert_equal [:warning], findings(code, 'project_positive_flow').map { |problem| problem[:kind] }, body
    end
  end

  def test_positive_flow_counts_structured_values_without_counting_scalar_text
    ["{ 'one' => 1, 'two' => 2 }", "['one', 'two']", "$kind ? { 'one' => 1, default => 2 }"].each do |value|
      code = "if $absent { $settings = undef } else { $settings = #{value} }"
      assert_equal [:warning], findings(code, 'project_positive_flow').map { |problem| problem[:kind] }, value
    end
    assert_empty findings("if $active { $value = stdlib::shell_escape(join($items, ' ')) } else { $value = 'plain' }", 'project_positive_flow')
    code = "if $absent { $value = 'A very long literal message\nwith several lines\nand no additional work' } else { $one = 1; $two = 2 }"
    assert_equal [:warning], findings(code, 'project_positive_flow').map { |problem| problem[:kind] }
  end

  def test_positive_flow_ignores_comments_whitespace_and_physical_line_count
    code = <<~'PUPPET'
      if $absent {
        # This explanation does not add executable work.
        # Nor does its continuation.

        $value = undef
      } else { $one = 1; $two = 2 }
    PUPPET
    assert_equal [[1, :warning]], findings(code, 'project_positive_flow').map { |problem| problem.values_at(:line, :kind) }
    assert_equal [:warning], findings(code.gsub("\n", "\r\n"), 'project_positive_flow').map { |problem| problem[:kind] }
    assert_empty findings("$content = 'if $absent { short } else { long }'", 'project_positive_flow')
  end

  def test_positive_flow_compares_individual_elsif_arms_and_retains_priority_requirements
    valid = "if $first { $one = 1; $two = 2 } elsif $second { $one = 3; $two = 4 } else { $one = 5; $two = 6 }"
    assert_empty findings(valid, 'project_positive_flow')
    reversed = "if $first { $one = 1 } elsif $second { $one = 2; $two = 3 } else { $one = 4 }"
    assert_equal [:warning], findings(reversed, 'project_positive_flow').map { |problem| problem[:kind] }
    final_else = "if $first { $one = 1; $two = 2; $three = 3 } elsif $second { $one = 4 } else { $one = 5; $two = 6 }"
    problems = findings(final_else, 'project_positive_flow')
    assert_equal [:warning], problems.map { |problem| problem[:kind] }
    assert_includes problems.first[:message], 'elsif priority'
    assert_empty findings("if $first { $one = 1; $two = 2 } elsif $second { $one = 3 }", 'project_positive_flow')
  end

  def test_positive_flow_treats_an_explicit_nested_if_as_nested_work
    code = "if $first { $one = 1; $two = 2 } else { if $second { $one = 3; $two = 4 } else { $one = 5; $two = 6 } }"
    assert_equal [:warning], findings(code, 'project_positive_flow').map { |problem| problem[:kind] }
  end

  def test_positive_flow_applies_the_same_branch_order_to_unless
    assert_equal [:warning], findings("unless $active { $value = undef } else { $one = 1; $two = 2 }", 'project_positive_flow').map { |problem| problem[:kind] }
    assert_empty findings("unless $active { $one = 1; $two = 2 } else { $value = undef }", 'project_positive_flow')
  end
end
