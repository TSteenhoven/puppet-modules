# frozen_string_literal: true

module ProjectLint
  module Layout
    # Distinguish literal arrays from type arguments and group nested arrays for one fix.
    class ArrayPlans
      def initialize(check, positions)
        @check = check
        @positions = positions
        @closings = check.bracket_closings
      end

      def plans
        @plans ||= @check.model.each_node(Model::M::LiteralList).filter_map { |node, parents| plan(node, parents) }
      end

      def plan(node, parents)
        opening = @positions.fetch([node.line, node.pos])
        closing = @closings[opening]
        return unless closing && closing.line > node.line

        { node: node, opening: opening, closing: closing, extra: resource_indent(node, parents),
          elements: node.values.map { |value| @positions.fetch([value.line, value.pos]) } }
      end

      def resource_indent(node, parents)
        parents.last.is_a?(Model::M::ResourceBody) && parents[-2].line == node.line ? 2 : 0
      end

      def covers?(parent, child)
        parent.offset <= child.offset && parent.offset + parent.length >= child.offset + child.length
      end

      def group(plan)
        outer = plans.find { |candidate| covers?(candidate[:node], plan[:node]) }
        plans.select { |candidate| covers?(outer[:node], candidate[:node]) }
      end
    end
  end
end
