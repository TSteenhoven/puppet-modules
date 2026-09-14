# frozen_string_literal: true

require_relative '../model'
require_relative '../nullability'

module ProjectLint
  # Implements the project_templates check through the native Puppet-lint contract.
  module TemplatesCheck
    include ProjectLint::ModelCheck

    def check
      model.each_node do |node, _|
        next unless node.is_a?(ProjectLint::Model::M::CallNamedFunctionExpression)
        next unless %w[epp inline_epp].include?(node.functor_expr.value)

        issue(node, 'Render generated configuration with template(...) and ERB')
      end
    end
  end
end
