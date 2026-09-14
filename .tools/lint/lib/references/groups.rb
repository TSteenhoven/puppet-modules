# frozen_string_literal: true

module ProjectLint
  module References
    # Group sibling references without crossing nested arrays or unresolved operands.
    module Groups
      def prepare_references
        @source_tokens = tokens
        @positions = tokens.to_h { |token| [[token.line, token.column], token] }
        @closings = bracket_closings
        @fixes = []
        @handled = {}.compare_by_identity
        @type_names = model.nodes.filter_map do |node, _parents|
          node.name.downcase if node.is_a?(Model::M::TypeAlias) || node.is_a?(Model::M::TypeDefinition)
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

      def reference_groups(node)
        node.values.each_with_index.group_by { |value, _index| reference?(value) ? value.left_expr.value : nil }
      end

      def safe_merge?(node, entries)
        entries.length == 1 || node.values[entries.first.last..entries.last.last].all? do |value|
          literal_reference?(value)
        end
      end

      def reference_wrapper(node, parents, entries, relationship)
        parent = parents.reverse.find { |ancestor| !ancestor.is_a?(Model::M::ParenthesizedExpression) }
        node if relationship && entries.length == node.values.length && !parent.is_a?(Model::M::LiteralList)
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
  end
end
