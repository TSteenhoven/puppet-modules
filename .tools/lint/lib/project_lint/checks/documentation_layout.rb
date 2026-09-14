# frozen_string_literal: true

require 'project_lint/ast'
require 'project_lint/strings_documentation'
require 'project_lint/token_helpers'

# Project-owned Puppet lint rules.
module ProjectLint
  # Native checks and their local analyses.
  module Checks
    # Coordinate documentation analysis and native fixes without exposing source values.
    module DocumentationLayout
      include AstCheck
      include StringsDocumentation
      include TokenHelpers

      DECLARATIONS = [Ast::M::HostClassDefinition, Ast::M::ResourceTypeDefinition, Ast::M::FunctionDefinition,
                      Ast::M::TypeAlias, Ast::M::TypeDefinition].freeze

      def report(row, message, replacement = nil)
        message += ' [review] Adjust manually; this construct cannot be safely rewritten' unless replacement
        @edits << { row: row, replacement: replacement }
        notify(:warning, message: message, line: row[:line], column: row[:indent].length + 1, edit: @edits.length - 1)
      end

      def documented_declarations
        ast.nodes.map(&:first).select { |node| self.class::DECLARATIONS.any? { |type| node.is_a?(type) } }
      end

      def check
        @source_tokens = tokens
        @edits = []
        rows = documentation_blocks(documented_declarations).flat_map do |_declaration, block|
          inspect_block(block)
          block
        end
        inspect_suppressions(rows)
      end

      # Track tag continuations, literal fences and indentation within a documentation block.
      module RowState
        def reset_block_state
          @previous = nil
          @tag = nil
          @literal = nil
          @structured_section = false
          @example_started = false
        end

        def prepare_tag
          @current_tag = @literal ? nil : @text[/\A@(\w+)\b/, 1]
          reset_section if @current_tag
          @separator = separator_needed?
          @tag = @current_tag if @current_tag
          @tag = nil if @separator && !@current_tag
          @tag = nil if summary_overview?
        end

        def reset_section
          @structured_section = false
          @example_started = false
        end

        def separator_needed?
          return false unless @previous && !@previous[:text].strip.empty?

          @current_tag || (@tag == 'summary' && !@text.start_with?(' '))
        end

        def summary_overview?
          @tag == 'summary' && @previous && @previous[:text].strip.empty? &&
            !@text.start_with?(' ') && !@current_tag
        end

        def prepare_structure
          @continuation = !@current_tag && @tag
          @prefix = @continuation ? '  ' : ''
          @content = @text.lstrip
          fence = @content[/\A(`{3,}|~{3,})/, 1]
          @structured_section ||= structured_content?(fence)
          @structured = @literal || @structured_section || @text.end_with?('  ', '\\')
          update_fence(fence) if fence
        end

        def structured_content?(fence)
          fence || structured_prose?(@content) || @text.start_with?(@continuation ? '      ' : '    ')
        end

        def update_fence(fence)
          if @literal
            @literal = nil if fence[0] == @literal[0] && fence.length >= @literal.length && @content.strip == fence
          else
            @literal = fence
          end
        end

        def prepare_indentation
          @example = @continuation && @tag == 'example'
          @wrong_indent = @continuation && !@text.start_with?('  ')
          @wrong_indent ||= initial_example_indent?
          @example_started = true if @example
          @wrong_indent ||= extra_continuation_indent?
          @summary_continuation = @continuation && @tag == 'summary'
        end

        def initial_example_indent?
          @example && !@example_started && @text[/\A */].length != 2
        end

        def extra_continuation_indent?
          @continuation && !@example && !@structured && @text.start_with?('   ') && !@text.start_with?('      ')
        end
      end

      # Visit documentation rows while preserving blank lines and suppression controls.
      module RowInspection
        def inspect_block(rows)
          reset_block_state
          rows.each_with_index { |row, index| inspect_row(row, index, rows) }
        end

        def inspect_row(row, index, rows)
          @row = row
          @text = row[:text]
          return if control?(@text)

          if @text.strip.empty?
            inspect_blank_row
          else
            inspect_content(index, rows)
          end
          @previous = row
        end

        def inspect_blank_row
          return if @row[:token] && @text.empty?

          report(@row, 'Separate Puppet Strings sections with a blank comment line (#)', [''])
        end
      end

      def inspect_content(index, rows)
        prepare_tag
        prepare_structure
        prepare_indentation
        check_example(index, rows) if @current_tag == 'example'
        report(@row, 'Keep @summary on one line; move additional explanation to the overview') if @summary_continuation
        format_row
      end

      def check_example(index, rows)
        report(@row, 'Put the example description on the @example line') unless @text.match?(/\A@example\s+\S/)
        following = rows.drop(index + 1).find { |entry| !entry[:text].strip.empty? && !control?(entry[:text]) }
        return if following && !following[:text].start_with?('@')

        report(@row, 'Put example code on indented comment lines below @example')
      end

      def format_row
        prepare_layout_replacement
        inspect_length
        wrap_long_row
        finalize_replacement
        report(@row, @messages.join('; '), @replacement) if @messages.any?
      end

      def prepare_layout_replacement
        @replacement = nil
        @messages = []
        @messages << 'Separate Puppet Strings sections with a blank comment line (#)' if @separator
        @messages << 'Puppet Strings continuation lines must be indented with two spaces' if @wrong_indent
        @replacement = [@prefix + @content] if @wrong_indent && wrapping_allowed?
        @replacement = [@text] if @separator && !@wrong_indent
      end

      def wrapping_allowed?
        !@example && !@structured && !@summary_continuation
      end

      def replacement_exceeds_maximum?
        @messages.any? { |message| message.include?('maximum') } &&
          @replacement&.any? { |line| @row[:indent].length + 2 + line.length > 140 }
      end

      def finalize_replacement
        @replacement = nil if replacement_exceeds_maximum?
        @replacement = [''] + @replacement if @separator && @replacement
      end

      # Apply prose width limits while preserving unbreakable atoms and example code.
      module LineWidth
        def inspect_length
          @width = manifest_lines[@row[:line] - 1].length
          @atoms = prose_atoms(@content)
          @row[:exception] = @width > 140 && unbreakable_row? && !%w[summary example].include?(@current_tag)
          message = width_message
          return unless message

          @messages << message << wrapping_message
          @replacement = nil
        end

        def unbreakable_row?
          return literal_example?(@content, @row[:indent].length + 4) if @example

          @atoms&.any? { |atom| @row[:indent].length + 2 + @prefix.length + atom.length > 140 }
        end

        def width_message
          ignored = PuppetLint::Data.ignore_overrides.fetch(:'140chars', {}).key?(@row[:line])
          if @width > 140 && !(@row[:exception] && ignored)
            'Puppet Strings documentation exceeds the maximum 140-character line length'
          elsif preferred_width_problem?
            'Puppet Strings documentation exceeds the preferred 120-character line width'
          end
        end

        def preferred_width_problem?
          @width > 120 && !@row[:exception] && !@example && !(@atoms && @atoms.length == 1)
        end

        def wrapping_message
          case @current_tag
          when 'summary' then 'Shorten @summary and move the full description into the overview'
          when 'example' then 'Keep the @example title on one line and shorten it manually'
          else 'Wrap documentation across comment lines; preserve literal values and example code'
          end
        end

        def wrap_long_row
          return unless @width > 120 && wrapping_allowed?

          if @current_tag == 'param'
            wrap_parameter
          elsif !@current_tag
            wrapped = wrap_prose(@content, @row[:indent].length + 2 + @prefix.length)
            @replacement = wrapped.map { |line| @prefix + line } if wrapped
          end
        end

        def wrap_parameter
          header = @content.match(/\A(@param\s+(?:\[[^\]]+\]\s+)?\w+)\s+(.+)\z/)
          wrapped = header && wrap_prose(header[2], @row[:indent].length + 4)
          @replacement = [header[1]] + wrapped.map { |line| "  #{line}" } if wrapped
        end
      end

      # Inspect paired width suppressions and identify directives that can be removed safely.
      module Suppressions
        def suppression_controls(token)
          token.value.strip.split.take_while { |word| word.start_with?('lint:') }
        end

        def standalone_control?(token)
          %i[COMMENT SLASH_COMMENT MLCOMMENT].include?(token.type) && control?(token.value.strip) &&
            manifest_lines[token.line - 1][0, token.column - 1].strip.empty?
        end

        def inspect_suppressions(rows)
          @rows_by_line = rows.to_h { |row| [row[:line], row] }
          stack = []
          @source_tokens.select { |token| standalone_control?(token) }.each do |token|
            if suppression_controls(token).first == 'lint:endignore'
              inspect_suppression_pair(stack.pop, token)
            else
              stack << token
            end
          end
        end

        def inspect_suppression_pair(opening, closing)
          return unless opening && suppression_controls(opening).include?('lint:ignore:140chars')

          affected = ((opening.line + 1)...closing.line).filter_map { |line| @rows_by_line[line] }
          return unless affected.any? { |row| normal_prose?(row) }

          report_suppression(opening, closing, removable_suppression?(opening, closing, affected))
        end

        def report_suppression(opening, closing, removable)
          @edits << { remove: removable ? [opening, closing] : nil }
          notify(:warning, message: suppression_message(removable), line: opening.line, column: opening.column,
                           edit: @edits.length - 1)
        end

        def normal_prose?(row)
          !row[:text].strip.empty? && !control?(row[:text]) && !row[:exception]
        end

        def removable_suppression?(opening, closing, affected)
          opening.value.strip == 'lint:ignore:140chars' && closing.value.strip == 'lint:endignore' &&
            affected.length == closing.line - opening.line - 1 &&
            affected.none? { |row| row[:exception] || control?(row[:text]) }
        end

        def suppression_message(removable)
          message = 'Do not disable the 140-character rule for normal Puppet Strings documentation; ' \
                    'wrap the documentation instead'
          unless removable
            message += ' [review] Narrow the suppression manually, preserving literal values and other checks'
          end
          message
        end
      end

      def replace_line(token, replacement)
        # Native insertion at index zero requires an existing preceding token.
        token.value = replacement.shift.value
        index = tokens.index(token)
        replacement.each_with_index { |new_token, offset| add_token(index + 1 + offset, new_token) }
      end

      def fix(problem)
        edit = @edits.fetch(problem[:edit])
        return remove_directives(edit[:remove]) if edit[:remove]

        raise PuppetLint::NoFix unless edit[:replacement]

        replace_documentation_row(edit[:row], edit[:replacement])
      end

      # Rewrite documentation comments and remove safe standalone suppression pairs with native tokens.
      module CommentEdits
        def remove_directives(pair)
          raise PuppetLint::NoFix if ignored_span?(*pair)

          pair.each do |token|
            previous = token.prev_token
            following = token.next_token
            remove_token(previous) if previous&.type == :INDENT
            remove_token(following) if following&.type == :NEWLINE
            remove_token(token)
          end
        end

        def replace_documentation_row(row, replacement)
          rendered = replacement.map { |line| line.empty? ? '#' : "# #{line}" }.join("\n#{row[:indent]}")
          if row[:token]
            replace_line(row[:token], PuppetLint::Lexer.new.tokenise(rendered))
          else
            insert_comment(row)
          end
        end
      end

      def insert_comment(row)
        # Preserve the existing newline and indentation of a whitespace-only source line.
        anchor = @source_tokens.find { |token| token.line == row[:line] && token.type == :NEWLINE }
        add_token(tokens.index(anchor), PuppetLint::Lexer.new.tokenise('#').first)
      end
      include RowState
      include LineWidth
      include Suppressions
      include RowInspection
      include CommentEdits
    end
    PuppetLint.new_check(:project_documentation_layout) { include DocumentationLayout }
  end
end
