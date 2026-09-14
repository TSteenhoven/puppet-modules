# frozen_string_literal: true

module ProjectLint
  # Count structural work rather than formatting, scalar text or function names.
  class BranchSize
    M = Model::M
    STRUCTURAL = [M::AbstractResource, M::ResourceBody, M::AbstractAttributeOperation,
                  M::KeyedEntry, M::SelectorEntry].freeze
    HANDLERS = { M::BlockExpression => :block_size, M::IfExpression => :if_size,
                 M::CaseExpression => :case_size, M::LambdaExpression => :lambda_size }.freeze

    def size(node, statement: true)
      return 0 unless node.is_a?(M::Positioned)
      return 0 if node.is_a?(M::Nop)

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
      own += node.values.length if node.is_a?(M::LiteralList)
      own + node.enum_for(:_pcore_contents).sum { |child| size(child, statement: false) }
    end
  end
end
