# frozen_string_literal: true

require_relative '../model'
require_relative '../token_helpers'
require_relative '../references/context'
require_relative '../references/groups'
require_relative '../references/plan'
require_relative '../references/fixes'

module ProjectLint
  # Coordinate reference analysis and fixes while keeping diagnostics free of source values.
  module ResourceReferencesCheck
    include ModelCheck
    include TokenHelpers
    include References::Context
    include References::Groups
    include References::Fixes

    def check
      prepare_references
      model.each_node(Model::M::LiteralList) { |node, parents| inspect_list(node, parents) }
      model.each_node(Model::M::AccessExpression) { |node, parents| inspect_single_reference(node, parents) }
    end

    def inspect_references(references, relationship, wrapper = nil, safe_merge: true)
      plan = References::Plan.new(self, references, relationship, wrapper, safe_merge: safe_merge)
      return unless plan.needed?

      @fixes << plan.edit
      first = plan.bounds.first
      notify(:warning, message: plan.message, line: first.line, column: first.column, edit: @fixes.length - 1)
    end
  end
end
