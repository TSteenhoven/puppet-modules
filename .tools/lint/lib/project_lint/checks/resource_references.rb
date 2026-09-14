# frozen_string_literal: true

require 'project_lint/ast'
require 'project_lint/token_helpers'

# Project-owned Puppet lint rules.
module ProjectLint
  # Native checks and their local analyses.
  module Checks
    # Coordinate reference analysis and fixes while keeping diagnostics free of source values.
    module ResourceReferences
      # Describe reference spans and decide whether their titles can be rewritten safely.
      class ReferenceEdit
        def initialize(check, references, relationship, wrapper, safe_merge:)
          @check = check
          @references = references
          @relationship = relationship
          @wrapper = wrapper
          @safe_merge = safe_merge
          @titles = references.flat_map(&:keys)
          prepare_anchors(references, wrapper)
        end

        def prepare_anchors(references, wrapper)
          @occurrences = references.map do |reference|
            start = @check.reference_position(reference)
            [start, @check.reference_closing(start.next_code_token)]
          end
          @outer_opening = @check.reference_position(wrapper) if wrapper
          @outer_closing = @check.reference_closing(outer_opening) if wrapper
        end

        def literal?
          @titles.all? { |title| @check.literal_title?(title) }
        end

        def merged?
          @references.length > 1
        end

        def unordered?
          literal? && @titles.map(&:value) != @titles.map(&:value).sort
        end

        def change_titles?
          merged? || unordered?
        end

        def needed?
          change_titles? || @wrapper
        end

        def title_tokens
          literal? ? @titles.map { |title| @check.reference_position(title) } : []
        end

        def movable_titles?
          literal? && title_tokens.all? { |token| %i[SSTRING STRING NAME].include?(token.type) }
        end

        def safe_span?
          !ignored? && tokens.none? do |token|
            %i[COMMENT SLASH_COMMENT MLCOMMENT HEREDOC_OPEN].include?(token.type)
          end
        end

        def fixable?
          @relationship && @safe_merge && safe_span? && (!change_titles? || movable_titles?)
        end

        def edit
          anchors.merge(titles: @titles.zip(title_tokens), fixable: fixable?,
                        merged: merged?, change_titles: change_titles?)
        end

        def base_message
          if merged?
            'Merge references of the same resource type within the array and sort their titles alphabetically'
          elsif unordered?
            'Sort resource reference titles alphabetically'
          else
            'Remove the outer array around a single resource reference'
          end
        end

        def message
          text = base_message
          text += '; remove the outer array around the resulting single reference' if @wrapper && change_titles?
          unless fixable?
            text += ' [review] Verify relationship context, array shape, title order and comments ' \
                    'before changing this expression'
          end
          text
        end

        attr_reader :occurrences, :outer_opening, :outer_closing

        def first
          occurrences.first.first
        end

        def opening
          first.next_code_token
        end

        def closing
          occurrences.last.last
        end

        def span_first
          outer_opening || first
        end

        def span_last
          return outer_closing || closing unless occurrences.length > 1 && !outer_opening

          @check.trailing_reference_tokens(closing).last || closing
        end

        def tokens
          @check.token_span(span_first, span_last)
        end

        def ignored?
          @check.ignored_span?(span_first, span_last)
        end

        def anchors
          { first: first, opening: opening, closing: closing, occurrences: occurrences,
            outer_opening: outer_opening, outer_closing: outer_closing }
        end
      end

      include AstCheck
      include TokenHelpers

      def check
        prepare_references
        ast.each_node(Ast::M::LiteralList) { |node, parents| inspect_list(node, parents) }
        ast.each_node(Ast::M::AccessExpression) { |node, parents| inspect_single_reference(node, parents) }
      end

      def inspect_references(references, relationship, wrapper = nil, safe_merge: true)
        plan = ReferenceEdit.new(self, references, relationship, wrapper, safe_merge: safe_merge)
        return unless plan.needed?

        @fixes << plan.edit
        first = plan.first
        notify(:warning, message: plan.message, line: first.line, column: first.column, edit: @fixes.length - 1)
      end

      CONTAINERS = [Ast::M::Program, Ast::M::BlockExpression, Ast::M::HostClassDefinition, Ast::M::ResourceTypeDefinition,
                    Ast::M::NodeDefinition, Ast::M::IfExpression, Ast::M::RelationshipExpression, Ast::M::ParenthesizedExpression].freeze

      # Recognize relationship consumers and reject expressions that also supply ordinary values.
      module RelationshipContext
        def relationship_context?(node, parents)
          child = node
          parents.reverse_each do |parent|
            return consuming_context?(parent, child, parents) unless array_container?(parent)

            child = parent
          end
          false
        end

        def array_container?(node)
          node.is_a?(Ast::M::LiteralList) || node.is_a?(Ast::M::ParenthesizedExpression)
        end

        def consuming_context?(parent, child, parents)
          return safe_relationship?(parent, parents) if parent.is_a?(Ast::M::RelationshipExpression)

          parent.is_a?(Ast::M::AttributeOperation) && parent.value_expr.equal?(child) &&
            %w[require before notify subscribe].include?(parent.attribute_name)
        end

        def safe_relationship?(parent, parents)
          parents.take(parents.index(parent)).all? do |ancestor|
            self.class::CONTAINERS.any? do |type|
              ancestor.is_a?(type)
            end
          end
        end
      end

      def reference?(node)
        return false unless node.is_a?(Ast::M::AccessExpression) && node.left_expr.is_a?(Ast::M::QualifiedReference)

        name = node.left_expr.value
        return false if name != 'class' && Puppet::Pops::Types::TypeParser.type_map.key?(name)

        !@type_names.include?(name)
      end

      def literal_title?(node)
        node.is_a?(Ast::M::LiteralString) || node.is_a?(Ast::M::QualifiedName)
      end

      def literal_reference?(node)
        reference?(node) && node.keys.all? { |title| literal_title?(title) }
      end

      def prepare_references
        @source_tokens = tokens
        @positions = tokens.to_h { |token| [[token.line, token.column], token] }
        @closings = bracket_closings
        @fixes = []
        @handled = {}.compare_by_identity
        @type_names = ast.nodes.filter_map do |node, _parents|
          node.name.downcase if node.is_a?(Ast::M::TypeAlias) || node.is_a?(Ast::M::TypeDefinition)
        end
      end

      def reference_position(node)
        @positions.fetch([node.line, node.pos])
      end

      def reference_closing(token)
        @closings.fetch(token)
      end

      def trailing_reference_tokens(closing)
        @source_tokens.drop(@source_tokens.index(closing) + 1).take_while do |token|
          token.type == :COMMA || PuppetLint::Data.formatting_tokens.include?(token.type)
        end
      end

      # Group compatible references while retaining unsafe mixtures for manual review.
      module ReferenceGroups
        def reference_groups(node)
          node.values.each_with_index.group_by { |value, _index| reference?(value) ? value.left_expr.value : nil }
        end

        def safe_merge?(node, entries)
          entries.length == 1 || node.values[entries.first.last..entries.last.last].all? do |value|
            literal_reference?(value)
          end
        end

        def reference_wrapper(node, parents, entries, relationship)
          parent = parents.reverse.find { |ancestor| !ancestor.is_a?(Ast::M::ParenthesizedExpression) }
          node if relationship && entries.length == node.values.length && !parent.is_a?(Ast::M::LiteralList)
        end

        def inspect_group(node, parents, entries)
          group = entries.map(&:first)
          relationship = relationship_context?(node, parents)
          wrapper = reference_wrapper(node, parents, entries, relationship)
          inspect_references(group, relationship, wrapper, safe_merge: safe_merge?(node, entries))
          # AST equality ignores source positions; use occurrence identity.
          group.each { |reference| @handled[reference] = true }
        end

        def inspect_list(node, parents)
          reference_groups(node).each do |type, entries|
            inspect_group(node, parents, entries) if type
          end
        end

        def inspect_single_reference(node, parents)
          return unless reference?(node) && !@handled.key?(node)

          inspect_references([node], relationship_context?(node, parents))
        end
      end

      def fix(problem)
        edit = @fixes.fetch(problem[:edit])
        raise PuppetLint::NoFix unless edit[:fixable]

        removals = reference_removals(edit)
        unwrap_reference(edit) if edit[:outer_opening]
        apply_titles(edit, removals) if edit[:change_titles]
      end

      def reference_removals(edit)
        edit[:occurrences].drop(1).map do |first, last|
          comma = first.prev_code_token
          raise PuppetLint::NoFix unless comma&.type == :COMMA

          token_span(comma, last)
        end
      end

      def apply_titles(edit, removals)
        ordered = ordered_title_tokens(edit)
        if edit[:merged]
          merge_titles(edit, ordered, removals)
        else
          sort_titles(edit, ordered)
        end
      end

      # Sort, merge and unwrap reference titles while preserving indentation and surviving token anchors.
      module TitleEdits
        def ordered_title_tokens(edit)
          entries = edit[:titles].each_with_index.sort_by { |(title, _token), index| [title.value, index] }
          entries.map { |(_title, token), _index| token }
        end

        def sort_titles(edit, ordered)
          original = edit[:titles].map(&:last)
          slots = original.map { |token| tokens.index(token) }
          original.each { |token| remove_token(token) }
          slots.zip(ordered).each { |index, token| add_token(index, token) }
        end

        def unwrap_shift(edit)
          prefix = line_prefix(edit[:first])
          indent = line_prefix(edit[:outer_opening])[/\A[ \t]*/]
          prefix.match?(/\A[ \t]*\z/) ? [prefix.length - indent.length, 0].max : 0
        end

        def unwrap_reference(edit)
          shift = unwrap_shift(edit)
          unindent_reference(edit, shift) if shift.positive?
          token_span(edit[:outer_opening], edit[:first])[0...-1].each { |token| remove_token(token) }
          token_span(edit[:closing], edit[:outer_closing])[1..].each { |token| remove_token(token) }
        end

        def unindent_reference(edit, shift)
          token_span(edit[:first], edit[:closing]).each_cons(2) do |previous, token|
            next unless previous.type == :NEWLINE && %i[INDENT WHITESPACE].include?(token.type)

            token.value = token.value.sub(/\A {1,#{shift}}/, '')
          end
        end

        def merge_titles(edit, ordered, removals)
          opening = edit[:opening]
          closing = edit[:occurrences].first.last
          interior = token_span(opening, closing)[1...-1]
          replacement = render_titles(edit, closing, ordered)
          (interior + removals.flatten).each { |token| remove_token(token) }
          insert_tokens_after(opening, replacement)
        end

        def render_titles(edit, closing, ordered)
          multiline = edit[:opening].line != (edit[:outer_opening] ? edit[:closing] : closing).line
          indent = line_prefix(edit[:opening])[/\A[ \t]*/]
          separator = multiline ? ",\n#{indent}  " : ', '
          replacement = separated_titles(ordered, separator)
          return replacement unless multiline

          lex_reference("\n#{indent}  ") + replacement + lex_reference(",\n#{indent}")
        end

        def separated_titles(ordered, separator)
          ordered.each_with_index.flat_map do |token, index|
            prefix = index.positive? ? lex_reference(separator) : []
            [*prefix, token]
          end
        end
      end

      def lex_reference(text)
        PuppetLint::Lexer.new.tokenise(text)
      end
      include RelationshipContext
      include ReferenceGroups
      include TitleEdits
    end
    PuppetLint.new_check(:project_resource_references) { include ResourceReferences }
  end
end
