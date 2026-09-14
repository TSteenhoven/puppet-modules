# frozen_string_literal: true

require 'project_lint/ast'
require 'project_lint/shell_provenance'

# Project-owned Puppet lint rules.
module ProjectLint
  # Native checks and their local analyses.
  module Checks
    # Check effective exec command data through its lexical assignment provenance.
    module Shell
      include AstCheck

      def check
        ast.each_node(Ast::M::AttributeOperation) do |node, parents|
          next unless %w[command onlyif unless].include?(node.attribute_name)
          next unless exec_resource?(parents)

          provenance = ShellProvenance.new(ast, ast.scope_of(parents))
          next unless provenance.classify(node.value_expr) == :raw

          issue(node, 'Command data has no proven shell escaping origin; prepare dynamic words ' \
                      'with stdlib::shell_escape before composing the command')
        end
      end

      def exec_resource?(parents)
        resource = parents.reverse.find do |parent|
          parent.is_a?(Ast::M::ResourceExpression) || parent.is_a?(Ast::M::ResourceDefaultsExpression)
        end
        return false unless resource

        name = resource.is_a?(Ast::M::ResourceExpression) ? resource.type_name.value : resource.type_ref.cased_value
        name == (resource.is_a?(Ast::M::ResourceExpression) ? 'exec' : 'Exec')
      end
    end
    PuppetLint.new_check(:project_shell) { include Shell }
  end
end
