# frozen_string_literal: true

require_relative 'test_helper'

# Known resource titles may be extracted; unknown data and resource-reference arrays may not.
class ResourceDependenciesTest < Minitest::Test
  include LintTestSupport

  RULE = :project_resource_dependencies

  def input(expression = "concat($backup_packages, ['server'])")
    <<~PUPPET
      class example {
        # Install the backup tools.
        $backup_packages = ['alpha', 'beta']
        ensure_packages($backup_packages)

        # Register the consumer after its prerequisites.
        notify { 'consumer':
          require => concat([Package[#{expression}]], $admin_require),
        }
      }
    PUPPET
  end

  def expected
    code = input('$backup_required_packages').sub('[Package[$backup_required_packages]]',
                                                  'Package[$backup_required_packages]')
    code.sub('  # Register', <<~PUPPET.lines.map { |line| line.strip.empty? ? line : "  #{line}" }.join.chomp)
      # Prepare resource titles before constructing dependencies.
      $backup_required_packages = concat(
        $backup_packages,
        ['server'],
      )

      # Register
    PUPPET
  end

  def test_extracts_known_package_names_and_unwraps_reference_before_combining_other_dependencies
    assert_fix input, expected, RULE, :project_resource_references
  end

  def test_keeps_known_non_package_references_in_the_outer_concat
    declaration = "  $admin_require = [Exec['admin'], File['config']]\n\n"
    assert_fix input.sub('  # Register', "#{declaration}  # Register"),
               expected.sub('  # Prepare', "#{declaration}  # Prepare"), RULE, :project_resource_references
  end

  def test_unknown_and_conditional_package_names_require_review
    ["concat($unknown, ['server'])", 'concat($backup_packages, $unknown)',
     "concat($backup_packages, $enabled ? { true => ['server'], default => [] })"].each do |expression|
      assert_preserved input(expression), [:warning], review: true
    end
  end

  def test_resource_references_are_never_treated_as_package_names
    ["concat($backup_packages, [Exec['admin']])", 'concat($backup_packages, $admin_require)'].each do |expression|
      code = input(expression).sub('  # Register', "  $admin_require = [Exec['admin']]\n\n  # Register")
      assert_preserved code, [:warning], review: true
    end
  end

  def test_prepared_variables_and_outer_concat_are_clean
    assert_clean_passes expected
    assert_clean_passes input('$backup_packages').sub('concat([Package[$backup_packages]], $admin_require)',
                                                      'Package[$backup_packages]')
  end

  def test_comments_and_suppressions_prevent_partial_extraction
    code = input("concat($backup_packages, # Keep this explanation.\n    ['server'])")
    assert_preserved code, [:warning], review: true
    code = "# lint:ignore:project_resource_dependencies\n#{input}# lint:endignore\n"
    assert_preserved code, [:ignored]
  end

  def test_colliding_variable_names_are_preserved
    code = input.sub('class example {', 'class example (Array $backup_required_packages = []) {')
    assert_preserved code, [:warning], review: true
  end

  def test_other_resource_types_keep_their_own_titles_and_context_names
    %w[File Service Example::Item Class].each do |type|
      before = input.gsub('Package[', "#{type}[").gsub('backup_packages', 'config_files')
                    .sub('ensure_packages($config_files)', '$unused = $config_files')
                    .gsub("'alpha'", "'/etc/example/alpha.conf'").gsub("'server'", "'/etc/example/extra.conf'")
      after = expected.gsub('Package[', "#{type}[").gsub('backup_packages', 'config_files')
                      .gsub('backup_required_packages', 'config_required_files')
                      .sub('ensure_packages($config_files)', '$unused = $config_files')
                      .gsub("'alpha'", "'/etc/example/alpha.conf'").gsub("'server'", "'/etc/example/extra.conf'")
      assert_fix before, after, RULE, :project_resource_references
    end
  end

  def test_datatype_parameters_and_indexing_are_not_extracted
    ["$one = Enum[concat(['a'], ['b'])]",
     "$one = $data[concat(['a'], ['b'])]",
     "type Example::Choice = Enum['a', 'b']\n$one = Example::Choice[concat(['a'], ['b'])]"].each do |code|
      assert_clean_passes code
    end
  end
end
