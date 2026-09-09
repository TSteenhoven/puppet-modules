require_relative '../../model'

PuppetLint.new_check(:project_layout) do
  include ProjectLint::ModelCheck

  def check
    tokens.each do |token|
      next unless token.type == :COMMA && token.next_code_token
      following = token.next_code_token
      next if following.line != token.line || [:RBRACK, :RBRACE, :RPAREN].include?(following.type)

      if token.next_token.type != :WHITESPACE || token.next_token.value != ' '
        notify(:warning, message: 'Use one space after a same-line comma', line: token.line, column: token.column)
      end
    end
    (class_indexes + defined_type_indexes).each do |declaration|
      parameters = declaration[:param_tokens]
      next unless parameters && parameters.any?
      code_tokens = parameters.reject { |token| PuppetLint::Data.formatting_tokens.include?(token.type) }
      last = code_tokens.last
      next unless last && declaration[:name_token].line != last.line
      next if last.type == :COMMA

      notify(:warning, message: 'End a multiline parameter block with a trailing comma', line: last.line, column: last.column)
    end
  end
end

PuppetLint.new_check(:project_positive_flow) do
  include ProjectLint::ModelCheck

  def statements(node)
    node.is_a?(ProjectLint::Model::M::BlockExpression) ? node.statements : [node].compact
  end

  def failure?(node)
    node.is_a?(ProjectLint::Model::M::CallNamedFunctionExpression) && %w[fail warning].include?(node.functor_expr.value)
  end

  def check
    model.nodes.each do |node, _|
      next unless node.is_a?(ProjectLint::Model::M::IfExpression)
      main = statements(node.then_expr)
      fallback = statements(node.else_expr)
      next unless main.length == 1 && failure?(main.first)
      next if fallback.empty? || fallback.all? { |statement| failure?(statement) || statement.is_a?(ProjectLint::Model::M::Nop) }

      issue(node, 'Keep the substantive dependent branch first and the fail or warning branch in the final else')
    end
  end
end
