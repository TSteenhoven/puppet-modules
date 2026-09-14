# frozen_string_literal: true

require_relative '../model'
require_relative '../strings_documentation'
require_relative '../token_helpers'
require_relative '../documentation/row_state'
require_relative '../documentation/row_layout'
require_relative '../documentation/line_width'
require_relative '../documentation/suppressions'
require_relative '../documentation/fixes'

module ProjectLint
  # Coordinate documentation analysis and native fixes without exposing source values.
  module DocumentationLayoutCheck
    include ModelCheck
    include StringsDocumentation
    include TokenHelpers
    include Documentation::RowState
    include Documentation::RowLayout
    include Documentation::LineWidth
    include Documentation::Suppressions
    include Documentation::Fixes

    DECLARATIONS = [Model::M::HostClassDefinition, Model::M::ResourceTypeDefinition, Model::M::FunctionDefinition,
                    Model::M::TypeAlias, Model::M::TypeDefinition].freeze

    def report(row, message, replacement = nil)
      message += ' [review] Adjust manually; this construct cannot be safely rewritten' unless replacement
      @edits << { row: row, replacement: replacement }
      notify(:warning, message: message, line: row[:line], column: row[:indent].length + 1, edit: @edits.length - 1)
    end

    def documented_declarations
      model.nodes.map(&:first).select { |node| DECLARATIONS.any? { |type| node.is_a?(type) } }
    end

    def check
      @source_tokens = tokens
      @edits = []
      rows = documentation_blocks(documented_declarations).flat_map do |_declaration, block|
        inspect_block(block)
        block
      end
      inspect_suppressions(rows)
    end
  end
end
