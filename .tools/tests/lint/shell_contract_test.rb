# frozen_string_literal: true

require_relative 'check_test_case'

# Verify the shell contract contract with native lint diagnostics.
class ShellContractTest < CheckTestCase
  def test_shell_values_need_real_escaping_provenance
    safe = fixture(:safe)
    assert_empty findings(safe, 'project_shell')
    refute_empty findings(safe.sub('stdlib::shell_escape($argument)', '$argument'), 'project_shell')
    assert_empty findings(%q(exec { 'demo': command => '/bin/sh -c "printf %s \"$1\""' }), 'project_shell')
    assert_empty findings(safe.sub('command => $script', 'command => Sensitive.new($script)'), 'project_shell')
  end

  def test_optional_shell_guard_accepts_undef_without_accepting_unescaped_input
    code = fixture(:code)
    assert_empty findings(code, 'project_shell')
    refute_empty findings(code.sub('stdlib::shell_escape($argument)', '$argument'), 'project_shell')
  end

  def test_shell_scope_and_multiple_assignments
    code = fixture(:code)
    refute_empty findings(code, 'project_shell')
    mapped = fixture(:mapped)
    assert_empty findings(mapped, 'project_shell')
    refute_empty findings(mapped.sub('stdlib::shell_escape($argument)', '$argument'), 'project_shell')
    assigned = mapped.sub('stdlib::shell_escape($argument) }',
                          '$argument_shell = stdlib::shell_escape($argument); $argument_shell }')
    assert_empty findings(assigned, 'project_shell')
    refute_empty findings(assigned.sub('stdlib::shell_escape($argument)', '$argument'), 'project_shell')
  end
end
