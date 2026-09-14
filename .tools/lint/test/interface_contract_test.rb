# frozen_string_literal: true

require_relative 'test_helper'

# Verify the interface contract contract with native lint diagnostics.
class InterfaceContractTest < Minitest::Test
  include LintTestSupport

  def test_nested_parameter_types_and_multiline_defaults
    code = fixture('interface_contract/types_and_multiline_defaults_code')
    assert_empty findings(code, 'parameter_types')
    assert_empty findings(code, 'project_parameter_order')
    assert_empty findings(code, 'project_parameter_alignment')
    refute_empty findings('class example ($label = "demo") {}', 'parameter_types')
  end

  def test_optional_without_default_does_not_change_call_contract
    assert_empty findings('class example (String $z, Optional[String] $a) {}', 'project_parameter_order')
    refute_empty findings('class example (Optional[String] $a, String $z) {}', 'project_parameter_order')
    parsed = ProjectLint::Ast.new('class example (String $z, Optional[String] $a) {}')
    assert_nil parsed.declarations.first.parameters.last.value
  end

  def test_interface_calls_require_optional_parameters_without_defaults
    definition = 'define example (Optional[String] $value) {}'
    refute_empty findings("#{definition} example { 'synthetic': }", 'project_interface_calls')
    assert_empty findings("#{definition} example { 'synthetic': value => undef }", 'project_interface_calls')
    assert_empty findings("define example (String $value = 'default') {} example { 'synthetic': }",
                          'project_interface_calls')
  end

  def test_default_dependencies_and_explanatory_comment
    code = fixture('interface_contract/dependencies_and_explanatory_comment_code')
    assert_empty findings(code, 'project_parameter_order')
    refute_empty findings(code.sub(/ # Must[^\n]+/, ''), 'project_parameter_order')
    refute_empty findings('class example (String $listen_user = $user, String $user = "example") {}',
                          'project_parameter_order')
  end

  def test_alignment_including_mandatory_parameters
    valid = "class example (\n  String           $required,\n  Optional[String] $optional = undef,\n) {}\n"
    assert_empty findings(valid, 'project_parameter_alignment')
    refute_empty findings(valid.sub('String           $required', 'String $required'), 'project_parameter_alignment')
  end

  def test_documentation_matches_each_declaration
    valid = fixture('interface_contract/documentation_matches_each_declaration_valid')
    assert_empty findings(valid, 'project_documentation')
    refute_empty findings(valid.sub('@param label', '@param other'), 'project_documentation')
    refute_empty findings("#{valid}\nclass undocumented {}", 'project_documentation')
  end
end
