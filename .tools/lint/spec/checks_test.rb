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

  def test_positive_flow_does_not_reject_optional_absence_guards
    assert_empty findings("if !defined(Package['example']) { package { 'example': } }", 'project_positive_flow')
    refute_empty findings("if !defined(Class['example']) { fail('Missing parent') } else { file { '/tmp/example': } }", 'project_positive_flow')
    assert_empty findings("if defined(Class['example']) { file { '/tmp/example': } } else { fail('Missing parent') }", 'project_positive_flow')
  end
end
