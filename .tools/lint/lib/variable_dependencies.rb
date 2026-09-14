# frozen_string_literal: true

require_relative 'model'

module ProjectLint
  # Resolve reads while respecting assignment targets and lambda-local names.
  module VariableDependencies
    include ModelCheck

    def assignment_names(node)
      return [] unless node.is_a?(Model::M::AssignmentExpression)
      return [] unless node.left_expr.is_a?(Model::M::VariableExpression) || node.left_expr.is_a?(Model::M::LiteralList)

      model.references(node.left_expr)
    end

    # Lambda-local assignments and parameters shadow outer variables.
    def local_names(node)
      return [] unless node.is_a?(Model::M::Positioned)
      return [] if node.is_a?(Model::M::LambdaExpression)

      assignment_names(node) + node.enum_for(:_pcore_contents).flat_map { |child| local_names(child) }
    end

    def variable_reads(node, bound = [])
      return [] unless node.is_a?(Model::M::Positioned)

      case node
      when Model::M::VariableExpression then [node.expr.value] - bound
      when Model::M::AssignmentExpression then variable_reads(node.right_expr, bound)
      when Model::M::LambdaExpression then lambda_reads(node, bound)
      else node.enum_for(:_pcore_contents).flat_map { |child| variable_reads(child, bound) }
      end
    end

    def lambda_reads(node, bound)
      defaults = node.parameters.flat_map { |parameter| variable_reads(parameter.value, bound) }
      defaults + variable_reads(node.body, bound + node.parameters.map(&:name) + local_names(node.body))
    end
  end
end
