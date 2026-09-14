# frozen_string_literal: true

require 'project_lint/ast'

# Project-owned Puppet lint rules.
module ProjectLint
  # Native checks and their local analyses.
  module Checks
    # Implements the project_templates check through the native Puppet-lint contract.
    module Templates
      include ProjectLint::AstCheck

      def check
        ast.each_node do |node, _|
          next unless node.is_a?(ProjectLint::Ast::M::CallNamedFunctionExpression)
          next unless %w[epp inline_epp].include?(node.functor_expr.value)

          issue(node, 'Render generated configuration with template(...) and ERB')
        end
      end
    end
    PuppetLint.new_check(:project_templates) { include Templates }
  end
end
