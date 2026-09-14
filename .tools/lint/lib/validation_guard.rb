# frozen_string_literal: true

module ProjectLint
  # Locate the enclosing guard within the body of its class or defined type.
  class ValidationGuard
    M = Model::M
    attr_reader :path, :guard

    def initialize(check, node, parents)
      @check = check
      @node = node
      index = parents.rindex { |parent| declaration?(parent) }
      @path = index ? parents.drop(index) + [node] : []
      @guard_index = path.rindex { |parent| parent.is_a?(M::IfExpression) || parent.is_a?(M::CaseExpression) }
      @guard = @guard_index ? path[@guard_index] : node
    end

    def declaration?(node)
      node.is_a?(M::HostClassDefinition) || node.is_a?(M::ResourceTypeDefinition)
    end

    def eligible?
      path.any? && path.include?(path.first.body) && path.none?(M::FunctionDefinition)
    end

    def fallback
      return guard.else_expr if guard.is_a?(M::IfExpression)
      return unless guard.is_a?(M::CaseExpression)

      option = guard.options.last
      option.then_expr if option.values.all?(M::LiteralDefault)
    end

    def valid_branch?
      branch = fallback
      @check.diagnostic_branch?(branch) && @check.statements(branch).include?(@node)
    end

    def implementation_follows?
      path.take(@guard_index + 1).each_cons(2).any? do |parent, child|
        next false unless parent.is_a?(M::BlockExpression)

        body = @check.statements(parent)
        index = body.index(child)
        index && index < body.length - 1
      end
    end
  end
end
