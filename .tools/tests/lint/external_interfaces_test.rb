# frozen_string_literal: true

require_relative 'external_test_case'

# Verify module precedence, vendored interfaces and symlink boundaries downstream.
class ExternalInterfacesTest < ExternalTestCase
  def assert_interface_call_lines(expected_lines)
    [nil, 'synthetic'].each do |action|
      assert_cli_failure('manifests/site.pp', extra_env: { 'GITHUB_ACTION' => action })
      assert_interface_locations(expected_lines)
      annotations = @output.lines.grep(/^::warning .* \(check: project_interface_calls\)$/)
      assert_equal(action ? expected_lines.length : 0, annotations.length, @output + @errors)
    end
  end

  def assert_interface_locations(expected_lines)
    path = File.realpath(File.join(@project, 'manifests/site.pp'))
    expected = expected_lines.map { |line| "#{path}:#{line}" }
    actual = @output.scan(/^(.+:\d+):\d+: project_interface_calls: warning:/).flatten
    assert_equal expected, actual, @output + @errors
  end

  def test_external_interfaces_follow_module_order_and_keep_dependencies_outside_style_scope
    write('manifests/site.pp', fixture(:sample))
    assert_interface_call_lines([1, 2])
    # An earlier module shadows the whole later module, including absent nested manifests.
    write_shared('profile/manifests/init.pp', 'class profile {}')
    write_shared('profile/manifests/item.pp', 'define profile::item (String $value) {}')
    write('manifests/site.pp', fixture(:sample2))
    assert_interface_call_lines([1])
    replace_script("[File.join(project_root, 'modules'), lint_root]",
                   "[lint_root, File.join(project_root, 'modules')]")
    assert_interface_call_lines([2])
  end

  def test_explicit_modulepath_also_resolves_vendored_names_without_following_escaping_symlinks
    write('modules/stdlib/manifests/init.pp', 'class stdlib (String $value) {}')
    write('manifests/site.pp', "class { 'stdlib': }\n")
    assert_cli_failure('manifests/site.pp')
    assert_includes @output, 'project_interface_calls'
    write('outside/manifests/init.pp', 'class escaping (String $value) {}')
    File.symlink(File.join(@project, 'outside'), File.join(@project, 'modules/escaping'))
    write('manifests/site.pp', "class { 'escaping': }\n")
    assert_cli_success('manifests/site.pp')
    refute_includes @output, 'project_interface_calls'
  end

  def test_invalid_module_paths_fail_even_without_resource_calls
    original = read('.tools/lint.rb')
    ["['']", "['modules']", "[File.join(project_root, 'missing')]"].each do |paths|
      write('.tools/lint.rb', original.sub("[File.join(project_root, 'modules'), lint_root]", paths))
      write('manifests/site.pp', "$values = concat([1], [2])\n")
      assert_cli_failure('manifests/site.pp')
      assert_includes @errors, 'PROJECT_LINT_MODULEPATH'
    end
  end
end
