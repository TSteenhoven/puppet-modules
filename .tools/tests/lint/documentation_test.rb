require_relative 'test_helper'

class DocumentationTest < Minitest::Test
  include LintTestSupport

  PROSE = 'This class manages console packages and keyboard configuration, preserves explicit settings, and uses the host defaults when no override is supplied.'.freeze

  def lint(code, fix: false, rule: :project_documentation_layout)
    lint_checks(code, [rule], fix: fix)
  end

  def document(body, declaration = 'class example {}')
    "# @summary Manages the example.\n#\n#{body}#\n# @api public\n#{declaration}\n"
  end

  def assert_clean(code)
    problems, fixed = lint(code, fix: true)
    assert_empty problems
    assert_equal code, fixed
  end

  def assert_fix(code, expected)
    problems, unchanged = lint(code)
    refute_empty problems
    assert_equal code, unchanged
    problems, fixed = lint(code, fix: true)
    assert problems.all? { |problem| problem[:kind] == :fixed }, problems.inspect
    assert_equal expected, fixed
    assert_clean(fixed)
    fixed
  end

  def test_long_prose_wraps_at_words_and_reports_maximum
    code = document("# #{PROSE}\n")
    problems, = lint(code)
    assert_equal [[3, 1]], problems.map { |problem| problem.values_at(:line, :column) }
    assert_includes problems.first[:message], 'maximum 140-character'
    expected = document("# This class manages console packages and keyboard configuration, preserves explicit settings, and uses the host\n# defaults when no override is supplied.\n")
    assert_fix(code, expected)
  end

  def test_preferred_width_is_distinguished_from_hard_maximum
    code = document("# #{'word ' * 24}end.\n")
    problems, = lint(code)
    assert_includes problems.first[:message], 'preferred 120-character'
    refute_includes problems.first[:message], 'maximum'
    assert_clean(document("# #{'word ' * 22}end.\n"))
  end

  def test_exact_line_width_boundaries_include_the_comment_prefix
    [120, 121, 140, 141].each do |width|
      line = '# ' + 'word ' * ((width - 3) / 5)
      line += 'x' * (width - line.length)
      problems, = lint(document(line + "\n"))
      if width == 120
        assert_empty problems
      else
        assert_includes problems.first[:message], width > 140 ? 'maximum 140-character' : 'preferred 120-character'
      end
    end
    code = document('#' + ('word ' * 27) + "last\n")
    problems, = lint(code)
    assert_includes problems.first[:message], 'preferred 120-character'
    refute_includes problems.first[:message], 'maximum'
  end

  def test_summary_cannot_use_a_literal_length_exception
    code = "# lint:ignore:140chars\n# @summary `#{'x' * 150}`\n# lint:endignore\nclass example {}\n"
    problems, = lint(code)
    assert_includes problems.first[:message], 'Shorten @summary'
  end

  def test_wrapped_sentences_and_real_paragraphs_are_already_valid
    assert_clean(document("# This sentence continues\n# onto another comment line.\n#\n# Another paragraph starts here.\n"))
  end

  def test_summary_requires_manual_shortening_without_deleting_text
    code = "# @summary #{PROSE}\n#\n# @api public\nclass example {}\n"
    problems, fixed = lint(code, fix: true)
    assert_equal code, fixed
    assert_equal [:warning], problems.map { |problem| problem[:kind] }
    assert_includes problems.first[:message], '[review]'
    code = "# @summary Short summary.\n#   Additional explanation.\nclass example {}\n"
    problems, fixed = lint(code, fix: true)
    assert_equal code, fixed
    assert_includes problems.first[:message], 'Keep @summary on one line'
  end

  def test_summary_overview_and_tag_sections_get_comment_separators
    before = "# @summary Manages the example.\n# Description.\n# @example Include the class\n#   include example\n# @api public\nclass example {}\n"
    after = before.sub("example.\n# Description", "example.\n#\n# Description")
                  .sub("Description.\n# @example", "Description.\n#\n# @example")
                  .sub("include example\n# @api", "include example\n#\n# @api")
    assert_fix(before, after)
  end

  def test_long_inline_parameter_moves_its_description_below_the_tag
    body = "# @param label #{PROSE}\n"
    expected = "# @param label\n#   This class manages console packages and keyboard configuration, preserves explicit settings, and uses the host\n#   defaults when no override is supplied.\n"
    assert_fix(document(body), document(expected))
    assert_fix(document(body.sub('@param label', '@param [String] label')),
               document(expected.sub('@param label', '@param [String] label')))
  end

  def test_unparseable_long_parameter_after_wrapped_prose_keeps_its_warning
    body = "# #{PROSE}\n#\n# @param #{'x' * 145}\n"
    problems, fixed = lint(document(body), fix: true)
    assert_equal [:fixed, :warning], problems.map { |problem| problem[:kind] }
    assert_includes fixed, "# @param #{'x' * 145}\n"
    assert_includes problems.last[:message], '[review]'
  end

  def test_short_inline_parameters_are_allowed_and_parameter_order_is_preserved
    before = document("# @param first Short description.\n# @param second\n#   Another description.\n")
    after = before.sub("description.\n# @param second", "description.\n#\n# @param second")
    assert_fix(before, after)
  end

  def test_continuation_indentation_is_corrected_for_parameters_and_other_tags
    %w[param note return].each do |tag|
      ['', ' ', '   ', '    '].each do |indent|
        body = "# @#{tag} label\n# #{indent}Description with a default.\n"
        assert_fix(document(body), document("# @#{tag} label\n#   Description with a default.\n"))
      end
      assert_clean(document("# @#{tag} label\n#   Description with a default.\n"))
    end
  end

  def test_nested_example_code_and_blank_lines_remain_exact
    body = <<~'PUPPET'
      # @example Configure the class
      #   class { 'example':
      #     settings => {
      #       'key' => 'a value with spaces',
      #     },
      #   }
      #
      #   include another
    PUPPET
    assert_clean(document(body))
  end

  def test_example_code_is_never_wrapped_as_prose
    body = "# @example Configure the class\n#   notice('#{'word ' * 26}')\n"
    code = document(body)
    problems, fixed = lint(code, fix: true)
    assert_equal code, fixed
    assert_equal [:warning], problems.map { |problem| problem[:kind] }
    assert_includes problems.first[:message], '[review]'
  end

  def test_example_indentation_requires_manual_review
    code = document("# @example Include the class\n# include example\n")
    problems, fixed = lint(code, fix: true)
    assert_equal code, fixed
    assert_includes problems.first[:message], 'indented with two spaces'
  end

  def test_example_title_body_and_initial_indentation_are_required
    ["# @example\n#   include example\n", "# @example Include the class\n",
     "# @example Include the class\n#     include example\n"].each do |body|
      code = document(body)
      problems, fixed = lint(code, fix: true)
      assert_equal code, fixed
      refute_empty problems
      assert problems.all? { |problem| problem[:kind] == :warning }
    end
  end

  def test_inline_code_paths_and_embedded_whitespace_are_preserved
    body = "# #{'word ' * 18}`Package['example']` `/etc/default/keyboard` ``a `tick` and  spaces`` `true` `false` `undef`.\n"
    problems, fixed = lint(document(body), fix: true)
    assert problems.all? { |problem| problem[:kind] == :fixed }
    ["`Package['example']`", '`/etc/default/keyboard`', '``a `tick` and  spaces``', '`true`', '`false`', '`undef`'].each do |span|
      assert_includes fixed, span
    end
    assert fixed.lines.all? { |line| line.chomp.length <= 120 }
    assert_clean(fixed)
  end

  def test_multiple_paragraphs_are_not_joined_or_reordered
    code = document("# #{PROSE}\n#\n# Another paragraph.\n#\n# #{PROSE}\n")
    _, fixed = lint(code, fix: true)
    assert_equal code.split("\n#\n").map { |p| p.gsub(/\n# */, ' ').split.join(' ') },
                 fixed.split("\n#\n").map { |p| p.gsub(/\n# */, ' ').split.join(' ') }
    assert_clean(fixed)
  end

  def test_source_blank_line_is_replaced_with_a_comment
    before = document("# Description.\n\n# More detail.\n")
    assert_fix(before, before.sub("Description.\n\n", "Description.\n#\n"))
  end

  def test_whitespace_only_comment_is_normalized_without_adding_a_paragraph
    code = "# @summary Example.\n#   \n# @api public\nclass example {}\n"
    assert_fix(code, code.sub("#   \n", "#\n"))
  end

  def test_unnecessary_suppression_is_removed_and_long_prose_is_wrapped
    before = document("# lint:ignore:140chars\n# #{PROSE}\n# lint:endignore\n")
    _, expected = lint(document("# #{PROSE}\n"), fix: true)
    assert_fix(before, expected)
    assert_fix(document("# lint:ignore:140chars\n# Short prose.\n# lint:endignore\n"), document("# Short prose.\n"))
  end

  def test_unbreakable_inline_literal_requires_a_targeted_exception
    body = "# `#{'value  ' * 24}`\n"
    code = document(body)
    problems, fixed = lint(code, fix: true)
    assert_equal code, fixed
    assert_includes problems.first[:message], 'maximum 140-character'
    assert_clean(document("# lint:ignore:140chars\n#{body}# lint:endignore\n"))
  end

  def test_long_literal_in_example_can_have_a_targeted_exception
    assert_clean(document("# @example Literal value\n# lint:ignore:140chars\n#   $value = '#{'value ' * 30}'\n# lint:endignore\n"))
  end

  def test_long_identifier_between_preferred_and_maximum_width_is_not_split
    assert_clean(document("# /#{'x' * 125}\n"))
  end

  def test_url_does_not_hide_long_normal_prose
    problems, fixed = lint(document("# #{PROSE} https://example.org/path\n"), fix: true)
    assert problems.all? { |problem| problem[:kind] == :fixed }
    assert_includes fixed, 'https://example.org/path'
    assert_clean(fixed)
  end

  def test_unsafe_markdown_and_delimiters_require_review
    ["- #{PROSE}", "| #{PROSE} |", "[#{PROSE}](https://example.org)", "#{PROSE} `unclosed",
     "#{PROSE}  ", "#{PROSE}\\", "#{PROSE} \\`escaped\\`", "#{PROSE}\tvalue"].each do |text|
      code = document("# #{text}\n")
      problems, fixed = lint(code, fix: true)
      assert_equal code, fixed
      assert_includes problems.first[:message], '[review]'
    end
  end

  def test_fenced_and_indented_code_is_not_wrapped
    ["# ```text\n# #{PROSE}\n# ```\n", "#     #{PROSE}\n",
     "# @param value\n#       #{PROSE}\n"].each do |body|
      code = document(body)
      problems, fixed = lint(code, fix: true)
      assert_equal code, fixed
      refute_empty problems
      assert problems.all? { |problem| problem[:kind] == :warning }
    end
  end

  def test_nested_list_continuations_keep_their_indentation
    code = document("# @param value\n#   - First item.\n#     Continuation of the item.\n#\n#     #{PROSE}\n")
    problems, fixed = lint(code, fix: true)
    assert_equal code, fixed
    assert_equal [:warning], problems.map { |problem| problem[:kind] }
    assert_includes problems.first[:message], '[review]'
  end

  def test_fences_protect_tag_like_code_and_mismatched_closing_fences
    body = "# ````text\n# @param literal\n# ```\n# #{PROSE}\n# ````\n"
    code = document(body)
    problems, fixed = lint(code, fix: true)
    assert_equal code, fixed
    assert_equal [:warning], problems.map { |problem| problem[:kind] }
  end

  def test_wrapping_cannot_create_tags_or_markdown_structure
    ['@param value', '- an item', '1. an item', '> a quote', '# a heading'].each do |ending|
      code = document("# #{'x' * 117} #{ending}\n")
      problems, fixed = lint(code, fix: true)
      assert_equal code, fixed
      assert_includes problems.first[:message], '[review]'
    end
  end

  def test_nested_documentation_and_unicode_are_fixed_at_their_actual_width
    body = "# #{('één woord ' * 18).strip}\n"
    code = "class outer {\n" + document(body, 'class outer::inner {}').lines.map { |line| '  ' + line }.join + "}\n"
    problems, fixed = lint(code, fix: true)
    assert problems.all? { |problem| problem[:kind] == :fixed }
    assert_equal [[4, 3]], problems.map { |problem| problem.values_at(:line, :column) }
    assert fixed.lines.all? { |line| line.chomp.length <= 120 }
    assert_clean(fixed)
  end

  def test_multiple_declarations_and_nested_suppressions_preserve_their_scope
    first = document("# lint:ignore:140chars\n# #{PROSE}\n# lint:endignore\n")
    second = document("# #{PROSE}\n", 'define other {}')
    _, fixed = lint(first + "\n" + second, fix: true)
    assert_clean(fixed)
    code = document("# lint:ignore:140chars\n# lint:ignore:puppet_url_without_modules\n# Short prose.\n# lint:endignore\n# lint:endignore\n")
    problems, fixed = lint(code, fix: true)
    assert_equal code, fixed
    assert_includes problems.first[:message], '[review]'
  end

  def test_suppression_that_also_covers_puppet_code_requires_manual_narrowing
    code = "# lint:ignore:140chars\n" + document("# Short prose.\n") + "# lint:endignore\n"
    problems, fixed = lint(code, fix: true)
    assert_equal code, fixed
    assert_includes problems.first[:message], '[review]'
  end

  def test_short_typed_parameter_descriptions_satisfy_interface_validation
    code = "# @summary Example.\n#\n# @example Include the class\n#   include example\n#\n# @param [String] label Description.\n#\n# @api public\nclass example (String $label = 'demo') {}\n"
    assert_empty lint(code, rule: :project_documentation).first
  end

  def test_mixed_or_commented_suppressions_are_not_deleted
    [
      "# lint:ignore:140chars Preserve this reason.\n# Short description.\n# lint:endignore\n",
      "# lint:ignore:140chars lint:ignore:puppet_url_without_modules\n# Short description.\n# lint:endignore\n",
      "# lint:ignore:140chars\n# Short description.\n# `#{'value ' * 30}`\n# lint:endignore\n",
    ].each do |body|
      code = document(body)
      problems, fixed = lint(code, fix: true)
      assert_equal code, fixed
      assert_includes problems.last[:message], '[review]'
    end
  end

  def test_mentioning_a_length_directive_in_another_suppression_reason_does_not_disable_it
    code = document("# lint:ignore:puppet_url_without_modules This mentions lint:ignore:140chars in prose.\n# Short prose.\n# lint:endignore\n")
    assert_clean(code)
  end

  def test_code_suppression_survives_documentation_fix
    body = "# lint:ignore:140chars\n# #{PROSE}\n# lint:endignore\n"
    suffix = "$value = '#{'x' * 150}' # lint:ignore:140chars\n"
    _, fixed = lint(document(body) + suffix, fix: true)
    assert fixed.end_with?(suffix)
    assert_clean(fixed)
  end

  def test_comments_in_strings_and_ordinary_comments_are_outside_scope
    assert_clean("$value = @(TEXT)\n# #{PROSE}\nTEXT\n")
    assert_clean("$value = '\n# #{PROSE}\n'\n")
    assert_clean("# #{PROSE}\n$value = 'example'\n")
    assert_clean("/* # #{PROSE} */\n$value = 'example'\n")
  end

  def test_classes_defined_types_functions_and_type_aliases_use_the_same_check
    ['class example {}', 'define example () {}', 'function example () {}', 'type Example = String'].each do |declaration|
      problems, fixed = lint(document("# #{PROSE}\n", declaration), fix: true)
      assert problems.all? { |problem| problem[:kind] == :fixed }
      assert fixed.end_with?("#{declaration}\n")
      assert_clean(fixed)
    end
  end

  def test_diagnostics_do_not_disclose_source_values
    problems, = lint(document("# #{PROSE}\n"))
    refute_includes problems.to_json, 'console'
  end

  def test_interface_validation_still_checks_tag_order_with_blank_source_lines
    code = "# @summary Example.\n\n# @example Include the class\n#   include example\n#\n# @param label\n#   Description.\n#\n# @api public\nclass example (String $label = 'demo') {}\n"
    assert_empty lint(code, rule: :project_documentation).first
    refute_empty lint(code.sub('@param label', '@param other'), rule: :project_documentation).first
  end
end
