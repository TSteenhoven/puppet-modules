require_relative 'test_helper'

class ValidationFlowTest < Minitest::Test
  def findings(body, declaration = 'class example')
    lint = PuppetLint.new
    lint.path = 'example.pp'
    lint.code = "#{declaration} {\n#{body}\n}\n"
    lint.run
    lint.problems.select { |problem| problem[:check] == :project_positive_flow }
  end

  def test_nested_validation_else_arms_are_alternatives_not_trailing_implementation
    body = <<~'PUPPET'
      $ready = true
      if $ready {
        if $valid {
          notify { 'synthetic': }
        } else {
          fail('Invalid settings')
        }
      } else {
        fail('Missing prerequisite')
      }
    PUPPET
    ['class example', 'define example'].each do |declaration|
      assert_empty findings(body, declaration)
      assert_empty findings(body.gsub('fail(', 'warning('), declaration)
      assert_empty findings(body.gsub("\n", "\r\n"), declaration)
    end
  end

  def test_trailing_code_is_detected_at_every_enclosing_statement_block
    patterns = [
      "if $valid { notify { 'synthetic': } } else { fail('Invalid') }; $later = true",
      "if $outer { if $valid { notify { 'synthetic': } } else { fail('Invalid') }; notice('Later') }",
      "if $outer { if $valid { notify { 'synthetic': } } else { fail('Invalid') } }; notify { 'later': }",
      "if $first { if $second { if $valid { notice('Valid') } else { fail('Invalid') } } }; include later",
      "$value = if $valid { 'valid' } else { fail('Invalid') }; notice($value)",
      "[1].each |$value| { if $value > 0 { notice('Valid') } else { fail('Invalid') } }; notice('Later')",
      "[1].each |$value| { if $value > 0 { notice('Valid') } else { fail('Invalid') }; notice('Later') }",
    ]
    patterns.each do |body|
      problems = findings(body)
      assert_equal 1, problems.length, body
      assert_includes problems.first[:message], 'no implementation may follow'
    end
  end

  def test_direct_and_nonfinal_diagnostics_require_a_fallback_even_for_equal_size_branches
    %w[fail warning ::fail ::warning].each do |function|
      [
        "#{function}('Invalid'); notice('Later')",
        "#{function}('Invalid')",
        "if $invalid { #{function}('Invalid') }; notice('Later')",
        "if $invalid { #{function}('Invalid') } else { notice('Valid') }",
        "if $invalid { #{function}('Invalid') } else { $one = 1; $two = 2 }",
      ].each do |body|
        problems = findings(body)
        assert_equal 1, problems.length, body
        assert_includes problems.first[:message], 'final else'
      end
    end
  end

  def test_sequential_validations_must_be_nested
    body = "if $first { notice('First') } else { fail('First missing') }; if $second { notice('Second') } else { fail('Second missing') }"
    problems = findings(body)
    assert_equal 1, problems.length
    assert_includes problems.first[:message], 'no implementation may follow'
  end

  def test_multiple_final_diagnostics_and_message_preparation_keep_the_fallback_last
    body = <<~'PUPPET'
      if $valid {
        notice('Valid')
      } else {
        $keys = join($invalid_keys, ', ')
        $message = "Invalid keys: ${keys}"
        warning($message)
        fail('Cannot proceed')
      }
    PUPPET
    assert_empty findings(body)
    assert_empty findings(body.sub('} else {', "} elsif $alternative {\n  notice('Alternative')\n} else {"))
    ["notice('Regular code')", "$unrelated = true", "notify { 'synthetic': }"].each do |extra|
      assert_equal 1, findings(body.sub('  warning($message)', "  #{extra}\n  warning($message)")).length, extra
      assert_equal 1, findings(body.sub("  fail('Cannot proceed')", "  fail('Cannot proceed')\n  #{extra}")).length, extra
    end
  end

  def test_case_defaults_and_elsif_arms_follow_the_same_terminal_structure
    assert_empty findings("case $state { 'active': { notice('Active') } default: { fail('Invalid') } }")
    assert_equal 1, findings("case $state { 'active': { notice('Active') } default: { fail('Invalid') } }; notice('Later')").length
    assert_equal 1, findings("case $state { 'invalid': { fail('Invalid') } default: { notice('Valid') } }").length
    assert_equal 1, findings("case $state { default: { fail('Invalid') } 'active': { notice('Active') } }").length
    assert_empty findings("if $first { notice('First') } elsif $second { notice('Second') } else { fail('Neither') }")
    assert_equal 1, findings("if $first { notice('First') } elsif $invalid { fail('Invalid') } else { fail('Neither') }").length
    assert_empty findings("unless $invalid { notice('Valid') } else { fail('Invalid') }")
  end

  def test_outer_alternative_with_implementation_may_follow_a_nested_validation
    assert_empty findings("if $active { if $valid { notify { 'synthetic': } } else { fail('Invalid') } } else { notice('Inactive') }")
    assert_empty findings("case $state { 'active': { if $valid { notify { 'synthetic': } } else { fail('Invalid') } } default: { notice('Inactive') } }")
  end

  def test_declaration_boundaries_defaults_and_non_diagnostic_text_do_not_trigger_the_rule
    body = <<~'PUPPET'
      # warning('Only a comment')
      $text = 'fail("Only text")'
      $content = @(CONTENT)
      warning('Only heredoc content')
      CONTENT
      example::warning('A different function')
      example::fail('A different function')
    PUPPET
    assert_empty findings(body)
    assert_empty findings("if $valid { notice('Valid') } else { fail('Invalid') }\n}\nclass another {\nnotice('Other scope')")
    assert_empty findings("if $valid { notice('Valid') } else { fail('Invalid') }", "define example (String $value = fail('Required'))")
    assert_empty findings("notice('Regular class code')\n}\nfunction example::helper() { fail('Deferred function body')\n}\nclass another {\nnotice('Other scope')")
  end

  def test_generic_branch_sizing_still_applies_without_a_diagnostic_fallback
    assert_equal 1, findings("if $short { notice('Short') } else { $one = 1; $two = 2 }").length
    assert_empty findings("if $long { $one = 1; $two = 2 } else { notice('Short') }")
  end
end
