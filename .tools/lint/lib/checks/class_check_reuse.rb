# frozen_string_literal: true

require_relative '../variable_dependencies'
require_relative '../class_check_usage'

module ProjectLint
  # Require reuse for shared class-check variables and flag repeated evaluations.
  module ClassCheckReuseCheck
    include VariableDependencies

    def variable_reads(node, bound = [])
      return [] if node.is_a?(Model::M::HostClassDefinition) || node.is_a?(Model::M::ResourceTypeDefinition)

      super
    end

    def defined_call?(node)
      node.is_a?(Model::M::CallNamedFunctionExpression) &&
        node.functor_expr.value == 'defined' && node.arguments.length == 1
    end

    def class_check(node)
      return unless defined_call?(node)

      reference = node.arguments.first
      return unless model.named_type?(reference, 'Class', parameterized: true)
      return unless reference.keys.length == 1 && reference.keys.first.is_a?(Model::M::LiteralString)

      reference.keys.first.value.downcase.delete_prefix('::')
    end

    def declaration_nodes(declaration)
      model.nodes.select do |node, parents|
        (node.equal?(declaration.body) || parents.include?(declaration.body)) &&
          parents.reverse.find { |parent| @declarations.include?(parent) }.equal?(declaration)
      end
    end

    def check
      @declarations = model.declarations
      @declarations.each { |declaration| check_declaration(declaration) if declaration.body }
    end

    def check_declaration(declaration)
      nodes = declaration_nodes(declaration)
      calls = nodes.select { |node, _parents| class_check(node) }.group_by { |node, _parents| class_check(node) }
      calls.each_value do |occurrences|
        if occurrences.length > 1
          report_repeated(occurrences)
        else
          check_assignment(declaration, nodes, occurrences.first.last)
        end
      end
    end

    def report_repeated(occurrences)
      occurrences.drop(1).map(&:first).each do |call|
        issue(call, 'Evaluate repeated defined(Class[...]) checks once in a shared variable within this class ' \
                    'or define; preserve evaluation order')
      end
    end

    def check_assignment(declaration, nodes, parents)
      usage = ClassCheckUsage.new(self, declaration, nodes, parents)
      return unless usage.assigned_variable?

      reads = usage.reads
      issue(usage.assignment.left_expr, unused_message(reads)) if reads < 2
    end

    def unused_message(reads)
      if reads == 1
        'Inline a defined(Class[...]) result used only once; keep a shared variable only for repeated use ' \
          'and preserve evaluation order'
      else
        'Remove an unused defined(Class[...]) variable; verify indirect consumers before changing it'
      end
    end
  end
end
