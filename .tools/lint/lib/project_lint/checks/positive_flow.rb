# frozen_string_literal: true

require 'project_lint/variable_dependencies'

# Project-owned Puppet lint rules.
module ProjectLint
  # Native checks and their local analyses.
  module Checks
    # Keep validation fallbacks terminal and place larger implementation branches first.
    module PositiveFlow
      # Count statements and resource structure without counting literal text.
      class BranchSize
        STRUCTURAL = [Ast::M::AbstractResource, Ast::M::ResourceBody, Ast::M::AbstractAttributeOperation,
                      Ast::M::KeyedEntry, Ast::M::SelectorEntry].freeze
        HANDLERS = { Ast::M::BlockExpression => :block_size, Ast::M::IfExpression => :if_size,
                     Ast::M::CaseExpression => :case_size, Ast::M::LambdaExpression => :lambda_size }.freeze

        def size(node, statement: true)
          return 0 unless node.is_a?(Ast::M::Positioned)
          return 0 if node.is_a?(Ast::M::Nop)

          handler = HANDLERS.find { |type, _method| node.is_a?(type) }&.last
          handler ? public_send(handler, node) : expression_size(node, statement)
        end

        def block_size(node)
          node.statements.sum { |child| size(child) }
        end

        def if_size(node)
          1 + size(node.then_expr) + size(node.else_expr)
        end

        def case_size(node)
          1 + node.options.sum { |option| 1 + size(option.then_expr) }
        end

        def lambda_size(node)
          1 + size(node.body)
        end

        def expression_size(node, statement)
          own = statement || STRUCTURAL.any? { |type| node.is_a?(type) } ? 1 : 0
          own += node.values.length if node.is_a?(Ast::M::LiteralList)
          own + node.enum_for(:_pcore_contents).sum { |child| size(child, statement: false) }
        end
      end

      include AstCheck
      include VariableDependencies

      # Recognize branches containing only diagnostics and the assignments those diagnostics consume.
      module DiagnosticBranches
        def statements(node)
          entries = node.is_a?(Ast::M::BlockExpression) ? node.statements : [node].compact
          entries.grep_v(Ast::M::Nop)
        end

        def diagnostic?(node)
          node.is_a?(Ast::M::CallNamedFunctionExpression) &&
            %w[fail warning].include?(node.functor_expr.value.delete_prefix('::'))
        end

        def diagnostic_branch?(node)
          body = statements(node).reverse
          return false unless diagnostic?(body.first)

          needed = []
          body.each do |statement|
            needed = diagnostic_dependencies(statement, needed)
            return false unless needed
          end
          true
        end

        def diagnostic_dependencies(statement, needed)
          return needed | variable_reads(statement) if diagnostic?(statement)

          names = assignment_names(statement)
          (needed - names) | variable_reads(statement.right_expr) if (names & needed).any?
        end
      end

      def check
        @validation_guards = validation_guards
        @fallbacks = @validation_guards.grep(Ast::M::IfExpression).filter_map do |guard|
          guard.else_expr if diagnostic_branch?(guard.else_expr)
        end
        @positions = tokens.to_h { |token| [[token.line, token.column], token] }
        @branch_size = BranchSize.new
        ast.each_node(Ast::M::IfExpression) { |node, _parents| check_branch(node) }
      end

      def check_branch(node)
        return if @validation_guards.include?(node)
        return unless @branch_size.size(node.then_expr) < following_size(node.else_expr)

        issue(node, 'Put the larger code branch first and keep shorter handling in the final else; ' \
                    'preserve condition semantics and elsif priority')
      end

      # Compare individual elsif arms; explicit nested if expressions keep their own structural weight.
      def following_size(node)
        return 0 if @fallbacks.include?(node)

        if node.is_a?(Ast::M::IfExpression) && @positions.fetch([node.line, node.pos]).type == :ELSIF
          [@branch_size.size(node.then_expr), following_size(node.else_expr)].max
        else
          @branch_size.size(node)
        end
      end

      def validation_guards
        @reported = []
        @terminal = []
        ast.each_node do |node, parents|
          inspect_diagnostic(node, parents) if diagnostic?(node)
        end
        @reported | @terminal
      end

      def validation_path(node, parents)
        index = parents.rindex do |parent|
          parent.is_a?(Ast::M::HostClassDefinition) || parent.is_a?(Ast::M::ResourceTypeDefinition)
        end
        path = index ? parents.drop(index) + [node] : []
        path if path.any? && path.include?(path.first.body) && path.none?(Ast::M::FunctionDefinition)
      end

      def inspect_diagnostic(node, parents)
        path = validation_path(node, parents)
        return unless path

        index = path.rindex { |parent| parent.is_a?(Ast::M::IfExpression) || parent.is_a?(Ast::M::CaseExpression) }
        guard = index ? path[index] : node
        return if @reported.include?(guard)

        message = validation_message(node, guard, index ? path.take(index + 1) : [])
        record_validation(guard, message)
      end

      def record_validation(guard, message)
        issue(guard, message) if message
        (message ? @reported : @terminal) << guard
      end

      def fallback(guard)
        return guard.else_expr if guard.is_a?(Ast::M::IfExpression)
        return unless guard.is_a?(Ast::M::CaseExpression)

        option = guard.options.last
        option.then_expr if option&.values&.all?(Ast::M::LiteralDefault)
      end

      def implementation_follows?(path)
        path.each_cons(2).any? do |parent, child|
          next false unless parent.is_a?(Ast::M::BlockExpression)

          body = statements(parent)
          index = body.index(child)
          index && index < body.length - 1
        end
      end

      def validation_message(node, guard, path)
        branch = fallback(guard)
        if !diagnostic_branch?(branch) || !statements(branch).include?(node)
          'Put validation warning() and fail() calls in the final else (or case default), ' \
            'with regular implementation in the valid branch'
        elsif implementation_follows?(path)
          'Keep the remaining implementation inside the valid branch; no implementation may follow this validation ' \
            'or its enclosing blocks within the class or defined type'
        end
      end
      include DiagnosticBranches
    end
    PuppetLint.new_check(:project_positive_flow) { include PositiveFlow }
  end
end
