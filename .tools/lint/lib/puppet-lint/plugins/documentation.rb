require_relative '../../model'
require_relative '../../strings_documentation'
require_relative '../../token_helpers'

PuppetLint.new_check(:project_documentation) do
  include ProjectLint::ModelCheck
  include ProjectLint::StringsDocumentation

  def check
    documentation_blocks(model.declarations).each do |declaration, rows|
      text = rows.reject { |row| control?(row[:text]) }.map { |row| row[:text] }
      issue(declaration, 'Document the declaration with one non-empty @summary') unless text.count { |line| line.match?(/^@summary\s+\S/) } == 1
      issue(declaration, 'Document the declaration with @api public or @api private') unless text.count { |line| line.match?(/^@api (?:public|private)$/) } == 1
      issue(declaration, 'Provide a Puppet Strings @example') unless text.any? { |line| line.match?(/^@example\s+\S/) }
      documented = text.filter_map { |line| line[/^@param\s+(?:\[[^\]]+\]\s+)?(\w+)/, 1] }
      issue(declaration, 'Document every parameter exactly once, in declaration order') unless documented == declaration.parameters.map(&:name)
      text.each_with_index do |line, index|
        next unless line.start_with?('@param ')
        next if line.match?(/^@param\s+(?:\[[^\]]+\]\s+)?\w+\s+\S/) || (text[index + 1] && text[index + 1].match?(/^\s+\S/))

        issue(declaration, 'Give each @param a description of its contract and default meaning')
      end
    end
  end
end

PuppetLint.new_check(:project_documentation_layout) do
  include ProjectLint::ModelCheck
  include ProjectLint::StringsDocumentation
  include ProjectLint::TokenHelpers

  def report(row, message, replacement = nil)
    message += ' [review] Adjust manually; this construct cannot be safely rewritten' unless replacement
    @edits << { row: row, replacement: replacement }
    notify(:warning, message: message, line: row[:line], column: row[:indent].length + 1,
           edit: @edits.length - 1)
  end

  def inspect_block(rows)
    previous = nil
    tag = nil
    literal = nil
    structured_section = false
    example_started = false
    rows.each_with_index do |row, index|
      text = row[:text]
      next if control?(text)

      if text.strip.empty?
        report(row, 'Separate Puppet Strings sections with a blank comment line (#)', ['']) unless row[:token] && text.empty?
        previous = row
        next
      end

      current_tag = literal ? nil : text[/\A@(\w+)\b/, 1]
      structured_section = false if current_tag
      example_started = false if current_tag
      separator = current_tag && previous && !previous[:text].strip.empty?
      # A summary is a single-line tag. Untagged overview prose starts its own section.
      separator ||= tag == 'summary' && !current_tag && !text.start_with?(' ') && previous && !previous[:text].strip.empty?
      tag = current_tag if current_tag
      tag = nil if separator && !current_tag
      tag = nil if tag == 'summary' && previous && previous[:text].strip.empty? && !text.start_with?(' ') && !current_tag
      continuation = !current_tag && tag
      prefix = continuation ? '  ' : ''
      content = text.lstrip

      fence = content[/\A(`{3,}|~{3,})/, 1]
      structured_section ||= fence || structured_prose?(content) || text.start_with?(continuation ? '      ' : '    ')
      structured = literal || structured_section || text.end_with?('  ', '\\')
      if fence
        if literal
          literal = nil if fence[0] == literal[0] && fence.length >= literal.length && content.strip == fence
        else
          literal = fence
        end
      end
      example = continuation && tag == 'example'
      wrong_indent = continuation && !text.start_with?('  ')
      wrong_indent ||= example && !example_started && text[/\A */].length != 2
      example_started = true if example
      if current_tag == 'example'
        report(row, 'Put the example description on the @example line') unless text.match?(/\A@example\s+\S/)
        following = rows.drop(index + 1).find { |entry| !entry[:text].strip.empty? && !control?(entry[:text]) }
        report(row, 'Put example code on indented comment lines below @example') if !following || following[:text].start_with?('@')
      end
      # Extra indentation can be intentional Markdown code, nested lists, or example indentation.
      wrong_indent ||= continuation && !example && !structured && text.start_with?('   ') && !text.start_with?('      ')
      summary_continuation = continuation && tag == 'summary'
      report(row, 'Keep @summary on one line; move additional explanation to the overview') if summary_continuation

      replacement = nil
      messages = []
      messages << 'Separate Puppet Strings sections with a blank comment line (#)' if separator
      messages << 'Puppet Strings continuation lines must be indented with two spaces' if wrong_indent
      replacement = [prefix + content] if wrong_indent && !example && !structured && !summary_continuation
      replacement = [text] if separator && !wrong_indent

      width = manifest_lines[row[:line] - 1].length
      atoms = prose_atoms(content)
      unbreakable = atoms && atoms.any? { |atom| row[:indent].length + 2 + prefix.length + atom.length > 140 }
      unbreakable = literal_example?(content, row[:indent].length + 4) if example
      row[:exception] = width > 140 && unbreakable && !%w[summary example].include?(current_tag)
      ignored = PuppetLint::Data.ignore_overrides.fetch(:'140chars', {}).key?(row[:line])
      length_problem = false
      if width > 140 && !(row[:exception] && ignored)
        messages << 'Puppet Strings documentation exceeds the maximum 140-character line length'
        length_problem = true
      elsif width > 120 && !row[:exception] && !example && !(atoms && atoms.length == 1)
        messages << 'Puppet Strings documentation exceeds the preferred 120-character line width'
        length_problem = true
      end
      if length_problem
        messages << case current_tag
                    when 'summary' then 'Shorten @summary and move the full description into the overview'
                    when 'example' then 'Keep the @example title on one line and shorten it manually'
                    else 'Wrap documentation across comment lines; preserve literal values and example code'
                    end
      end

      replacement = nil if length_problem
      if width > 120 && !example && !structured && !summary_continuation
        if current_tag == 'param'
          header = content.match(/\A(@param\s+(?:\[[^\]]+\]\s+)?\w+)\s+(.+)\z/)
          wrapped = header && wrap_prose(header[2], row[:indent].length + 4)
          replacement = [header[1]] + wrapped.map { |line| '  ' + line } if wrapped
        elsif !current_tag
          wrapped = wrap_prose(content, row[:indent].length + 2 + prefix.length)
          replacement = wrapped.map { |line| prefix + line } if wrapped
        end
      end
      replacement = nil if messages.any? { |message| message.include?('maximum') } &&
                           replacement&.any? { |line| row[:indent].length + 2 + line.length > 140 }
      replacement = [''] + replacement if separator && replacement
      report(row, messages.join('; '), replacement) if messages.any?
      previous = row
    end
  end

  def inspect_suppressions(rows)
    by_line = rows.to_h { |row| [row[:line], row] }
    stack = []
    @source_tokens.each do |token|
      next unless [:COMMENT, :SLASH_COMMENT, :MLCOMMENT].include?(token.type)
      next unless control?(token.value.strip)
      next unless manifest_lines[token.line - 1][0, token.column - 1].strip.empty?

      controls = token.value.strip.split.take_while { |word| word.start_with?('lint:') }
      if controls.first == 'lint:endignore'
        opening = stack.pop
        next unless opening && opening.value.strip.split.take_while { |word| word.start_with?('lint:') }.include?('lint:ignore:140chars')

        affected = ((opening.line + 1)...token.line).filter_map { |line| by_line[line] }
        prose = affected.reject { |row| row[:text].strip.empty? || control?(row[:text]) || row[:exception] }
        next if prose.empty?

        # Remove only an exact, bounded, documentation-only directive pair. Never widen a code exception,
        # discard a reason, or close a combined/nested suppression belonging to another check.
        removable = opening.value.strip == 'lint:ignore:140chars' && token.value.strip == 'lint:endignore' &&
                    affected.length == token.line - opening.line - 1 &&
                    affected.none? { |row| row[:exception] || control?(row[:text]) }
        @edits << { remove: removable ? [opening, token] : nil }
        notify(:warning, message: 'Do not disable the 140-character rule for normal Puppet Strings documentation; wrap the documentation instead' +
               (removable ? '' : ' [review] Narrow the suppression manually, preserving literal values and other checks'),
               line: opening.line, column: opening.column, edit: @edits.length - 1)
      else
        stack << token
      end
    end
  end

  def check
    @source_tokens = tokens
    @edits = []
    m = ProjectLint::Model::M
    declarations = model.nodes.map(&:first).select do |node|
      [m::HostClassDefinition, m::ResourceTypeDefinition, m::FunctionDefinition, m::TypeAlias, m::TypeDefinition].any? { |type| node.is_a?(type) }
    end
    rows = []
    documentation_blocks(declarations).each do |_, block|
      inspect_block(block)
      rows.concat(block)
    end
    inspect_suppressions(rows)
  end

  def replace_line(token, replacement)
    # Retain the anchor for other checks, and avoid insertion at index zero
    # (Data.insert in puppet-lint 5.1.1 assumes a preceding token).
    token.value = replacement.shift.value
    index = tokens.index(token)
    replacement.each_with_index { |new_token, offset| add_token(index + 1 + offset, new_token) }
  end

  def fix(problem)
    edit = @edits.fetch(problem[:edit])
    if edit[:remove]
      raise PuppetLint::NoFix if ignored_span?(*edit[:remove])

      edit[:remove].each do |token|
        previous = token.prev_token
        following = token.next_token
        remove_token(previous) if previous && previous.type == :INDENT
        remove_token(following) if following && following.type == :NEWLINE
        remove_token(token)
      end
      return
    end
    raise PuppetLint::NoFix unless edit[:replacement]

    row = edit[:row]
    rendered = edit[:replacement].map { |line| line.empty? ? '#' : '# ' + line }.join("\n#{row[:indent]}")
    if row[:token]
      replace_line(row[:token], PuppetLint::Lexer.new.tokenise(rendered))
    else
      # Preserve the existing newline and indentation of a whitespace-only source line.
      anchor = @source_tokens.find { |token| token.line == row[:line] && token.type == :NEWLINE }
      add_token(tokens.index(anchor), PuppetLint::Lexer.new.tokenise('#').first)
    end
  end
end

PuppetLint.new_check(:project_suppressions) do
  def check
    tokens.select { |token| [:COMMENT, :MLCOMMENT, :SLASH_COMMENT].include?(token.type) }.each do |token|
      # Match actual control comments; mentioning a directive in prose or a string does not suppress a check.
      next unless token.value.strip.match?(/\Alint:(?:ignore|endignore)\b/)
      controls = token.value.strip.split.take_while { |word| word.start_with?('lint:') }
      next if controls == ['lint:endignore']
      allowed = %w[lint:ignore:140chars lint:ignore:puppet_url_without_modules]
      next if controls.any? && controls.all? { |control| allowed.include?(control) }

      notify(:error, message: 'Only targeted 140chars and puppet_url_without_modules suppressions are allowed; fix other lint violations', line: token.line, column: token.column)
    end
  end
end
