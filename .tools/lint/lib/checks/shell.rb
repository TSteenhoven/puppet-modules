# frozen_string_literal: true

require_relative '../shell_provenance'

module ProjectLint
  # Check effective exec command data through its lexical assignment provenance.
  module ShellCheck
    include ModelCheck

    def check
      model.each_node(Model::M::AttributeOperation) do |node, parents|
        next unless %w[command onlyif unless].include?(node.attribute_name)
        next unless exec_resource?(parents)

        provenance = ShellProvenance.new(model, model.scope_of(parents))
        next unless provenance.classify(node.value_expr) == :raw

        issue(node, 'Command data has no proven shell escaping origin; prepare dynamic words ' \
                    'with stdlib::shell_escape before composing the command')
      end
    end

    def exec_resource?(parents)
      resource = parents.reverse.find do |parent|
        parent.is_a?(Model::M::ResourceExpression) || parent.is_a?(Model::M::ResourceDefaultsExpression)
      end
      return false unless resource

      name = resource.is_a?(Model::M::ResourceExpression) ? resource.type_name.value : resource.type_ref.cased_value
      name == (resource.is_a?(Model::M::ResourceExpression) ? 'exec' : 'Exec')
    end
  end
end
