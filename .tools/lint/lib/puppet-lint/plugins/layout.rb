require_relative '../../model'

module ProjectLint
  # Use lexer comments for section boundaries; comment-like text inside strings is ordinary data.
  module SectionLayout
    include ModelCheck

    def control_comment?(token)
      token.value.strip.match?(/\Alint:(?:ignore|endignore)\b/)
    end

    def comment_end_line(token)
      token.line + token.value.count("\n")
    end

    # Native code-token links omit comments; walk the complete token list at comment boundaries.
    def adjacent_code(token, direction)
      token = token.public_send(direction)
      token = token.public_send(direction) while token && PuppetLint::Data.formatting_tokens.include?(token.type)
      token
    end

    def comment_sections
      lines = PuppetLint::Data.manifest_lines
      sections = []
      tokens.each do |token|
        next unless [:COMMENT, :MLCOMMENT, :SLASH_COMMENT].include?(token.type)
        next unless lines[token.line - 1][0, token.column - 1].strip.empty?
        following = adjacent_code(token, :next_token)
        next if following && following.line <= comment_end_line(token)

        if sections.last && comment_end_line(sections.last.last) + 1 >= token.line
          sections.last << token
        else
          sections << [token]
        end
      end
      sections.filter_map do |section|
        # A closing suppression belongs to the preceding code, not to the next explanation.
        section = section.drop_while { |token| token.value.strip == 'lint:endignore' }
        section if section.any? { |token| !control_comment?(token) && !token.value.strip.empty? }
      end
    end
  end
end

PuppetLint.new_check(:project_comment_spacing) do
  include ProjectLint::SectionLayout

  def check
    comment_sections.each do |section|
      first = section.first
      previous = adjacent_code(first, :prev_token)
      next unless previous
      next if [:LBRACE, :LBRACK, :LPAREN].include?(previous.type)
      next if PuppetLint::Data.manifest_lines[first.line - 2].strip.empty?

      notify(:warning, message: 'Put a blank line before a standalone explanatory comment block', line: first.line, column: first.column)
    end
  end
end

PuppetLint.new_check(:project_resource_sections) do
  include ProjectLint::SectionLayout

  def check
    positions = tokens.to_h { |token| [[token.line, token.column], token] }
    sections = comment_sections
    model.nodes.each do |node, _|
      next unless [ProjectLint::Model::M::ResourceExpression, ProjectLint::Model::M::ResourceDefaultsExpression,
                   ProjectLint::Model::M::ResourceOverrideExpression].any? { |type| node.is_a?(type) }

      previous = positions.fetch([node.line, node.pos]).prev_code_token
      previous = previous.prev_code_token if previous && previous.type == :SEMIC
      next unless previous && previous.type == :RBRACE
      next if sections.any? { |section| section.first.line > previous.line && comment_end_line(section.last) == node.line - 1 }

      issue(node, 'Start a resource declaration after a closed block with a blank line and a preceding explanatory comment')
    end
  end
end

module ProjectLint::VariableDependencies
  include ProjectLint::ModelCheck

  def assignment_names(node)
    m = ProjectLint::Model::M
    return [] unless node.is_a?(m::AssignmentExpression)
    return [] unless node.left_expr.is_a?(m::VariableExpression) || node.left_expr.is_a?(m::LiteralList)

    model.references(node.left_expr)
  end

  # Lambda parameters and local assignments shadow outer variables; their names are not dependencies on the section.
  def local_names(node)
    return [] unless node.is_a?(ProjectLint::Model::M::Positioned)
    return [] if node.is_a?(ProjectLint::Model::M::LambdaExpression)

    assignment_names(node) + node.enum_for(:_pcore_contents).flat_map { |child| local_names(child) }
  end

  def variable_reads(node, bound = [])
    m = ProjectLint::Model::M
    return [] unless node.is_a?(m::Positioned)

    case node
    when m::VariableExpression
      [node.expr.value] - bound
    when m::AssignmentExpression
      variable_reads(node.right_expr, bound)
    when m::LambdaExpression
      defaults = node.parameters.flat_map { |parameter| variable_reads(parameter.value, bound) }
      defaults + variable_reads(node.body, bound + node.parameters.map(&:name) + local_names(node.body))
    else
      node.enum_for(:_pcore_contents).flat_map { |child| variable_reads(child, bound) }
    end
  end
end

PuppetLint.new_check(:project_variable_sections) do
  include ProjectLint::SectionLayout
  include ProjectLint::VariableDependencies

  # A matching call identifies a review candidate, not proof that moving its evaluation preserves behavior.
  def grouping_hint(node, parent, starts)
    m = ProjectLint::Model::M
    return '' unless parent.is_a?(m::BlockExpression) && node.right_expr.is_a?(m::CallNamedFunctionExpression)
    return '' if node.right_expr.lambda

    names = assignment_names(node)
    parent.statements.drop(parent.statements.index(node) + 1).each do |following|
      break if assignment_names(following).empty? || (variable_reads(following.right_expr) & names).any?

      section_line = starts[[following.left_expr.line, following.left_expr.pos]]
      call = following.right_expr
      if section_line && call.is_a?(m::CallNamedFunctionExpression) && !call.lambda && call.functor_expr.value == node.right_expr.functor_expr.value
        return "; consider the explained section at line #{section_line} with the same outer function, after checking purpose and evaluation order"
      end
    end
    ''
  end

  def check
    starts = comment_sections.filter_map do |section|
      following = adjacent_code(section.last, :next_token)
      [[following.line, following.column], section.first.line] if following && following.line == comment_end_line(section.last) + 1
    end.to_h
    positions = tokens.to_h { |token| [[token.line, token.column], token] }
    model.nodes.each do |node, parents|
      next if assignment_names(node).empty?

      position = [node.left_expr.line, node.left_expr.pos]
      next unless positions.fetch(position).prev_code_token&.type == :LBRACE
      next if starts.key?(position)

      message = 'Explain the variable group immediately inside the opening brace'
      issue(node.left_expr, message + grouping_hint(node, parents.last, starts))
    end
    model.nodes.each do |block, _|
      next unless block.is_a?(ProjectLint::Model::M::BlockExpression)

      annotated = false
      linked = false
      assigned = []
      block.statements.each do |node|
        names = assignment_names(node)
        if names.empty?
          annotated = false
          next
        end

        if starts.key?([node.left_expr.line, node.left_expr.pos])
          annotated = true
          linked = false
          assigned = []
        end
        next unless annotated

        # Independent settings may share an explanation. After an internal dependency, an unrelated value starts a new topic.
        related = (variable_reads(node.right_expr) & assigned).any?
        if linked && !related
          issue(node.left_expr, 'Start unrelated assignments after a dependent variable group with a blank line and a new explanatory comment')
          linked = false
          assigned = []
        end
        linked ||= related
        assigned.concat(names)
      end
    end
  end
end

PuppetLint.new_check(:project_if_sections) do
  include ProjectLint::SectionLayout
  include ProjectLint::VariableDependencies

  # Walk backwards through adjacent assignments that feed the condition, including indirect dependencies.
  def preparation_start(node, parents, positions)
    anchor = node
    parent = parents.last
    if parent.is_a?(ProjectLint::Model::M::AssignmentExpression) && parent.right_expr.equal?(node)
      anchor = parent
      parent = parents[-2]
    end
    target = anchor
    if parent.is_a?(ProjectLint::Model::M::BlockExpression)
      index = parent.statements.index(anchor)
      needed = variable_reads(node.test)
      following = node.else_expr
      while following.is_a?(ProjectLint::Model::M::IfExpression) && positions.fetch([following.line, following.pos]).type == :ELSIF
        needed |= variable_reads(following.test)
        following = following.else_expr
      end
      parent.statements.take(index).reverse_each do |previous|
        names = assignment_names(previous)
        break if (names & needed).empty?

        target = previous
        needed = (needed - names) | variable_reads(previous.right_expr)
      end
    end
    target.is_a?(ProjectLint::Model::M::AssignmentExpression) ? target.left_expr : target
  end

  def check
    positions = tokens.to_h { |token| [[token.line, token.column], token] }
    explained = comment_sections.filter_map do |section|
      following = adjacent_code(section.last, :next_token)
      [following.line, following.column] if following
    end
    model.nodes.each do |node, parents|
      next unless node.is_a?(ProjectLint::Model::M::IfExpression)
      next if positions.fetch([node.line, node.pos]).type == :ELSIF

      target = preparation_start(node, parents, positions)
      next if explained.include?([target.line, target.pos])

      issue(target, 'Explain the conditional above its preparatory variable assignments, or above the if/unless when there are none')
    end
  end
end

PuppetLint.new_check(:project_layout) do
  include ProjectLint::ModelCheck

  def check_opening_brace_spacing
    tokens.select { |token| token.type == :LBRACE }.each do |opening|
      following = opening.next_token
      # An inline comment belongs to the opening line. Multiline comments and strings have their own content.
      while following && following.line == opening.line &&
            [:WHITESPACE, :COMMENT, :SLASH_COMMENT, :MLCOMMENT].include?(following.type) && !following.value.include?("\n")
        following = following.next_token
      end
      next unless following && following.type == :NEWLINE && following.line == opening.line
      next unless PuppetLint::Data.manifest_lines[opening.line]&.strip == ''

      notify(:warning, message: 'Remove blank lines immediately after an opening brace', line: opening.line + 1, column: 1)
    end
  end

  def check
    check_opening_brace_spacing
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
  include ProjectLint::VariableDependencies

  def statements(node)
    entries = node.is_a?(ProjectLint::Model::M::BlockExpression) ? node.statements : [node].compact
    entries.reject { |entry| entry.is_a?(ProjectLint::Model::M::Nop) }
  end

  def diagnostic?(node)
    node.is_a?(ProjectLint::Model::M::CallNamedFunctionExpression) && %w[fail warning].include?(node.functor_expr.value.delete_prefix('::'))
  end

  def diagnostic_branch?(node)
    needed = []
    diagnostic_seen = false
    statements(node).reverse_each do |statement|
      if diagnostic?(statement)
        diagnostic_seen = true
        needed |= variable_reads(statement)
      elsif diagnostic_seen && (assignment_names(statement) & needed).any?
        needed = (needed - assignment_names(statement)) | variable_reads(statement.right_expr)
      else
        return false
      end
    end
    diagnostic_seen
  end

  # Follow statement containers up to the declaration, not source lines: sibling else/case arms
  # are alternative paths, while statements after any enclosing guard escape that validation.
  def implementation_follows?(path)
    path.each_cons(2).any? do |parent, child|
      next false unless parent.is_a?(ProjectLint::Model::M::BlockExpression)

      body = statements(parent)
      index = body.index(child)
      index && index < body.length - 1
    end
  end

  def check_validation_structure
    m = ProjectLint::Model::M
    reported = []
    terminal_guards = []
    model.nodes.each do |node, parents|
      next unless diagnostic?(node)

      scope_index = parents.rindex { |parent| parent.is_a?(m::HostClassDefinition) || parent.is_a?(m::ResourceTypeDefinition) }
      next unless scope_index

      path = parents.drop(scope_index) + [node]
      next unless path.include?(path.first.body)
      next if path.any? { |parent| parent.is_a?(m::FunctionDefinition) }

      guard_index = path.rindex { |parent| parent.is_a?(m::IfExpression) || parent.is_a?(m::CaseExpression) }
      guard = guard_index ? path[guard_index] : node
      next if reported.include?(guard)

      if guard.is_a?(m::IfExpression)
        fallback = guard.else_expr
        valid_branch = diagnostic_branch?(fallback) && statements(fallback).include?(node)
      elsif guard.is_a?(m::CaseExpression)
        option = guard.options.last
        fallback = option.then_expr
        valid_branch = option.values.all? { |value| value.is_a?(m::LiteralDefault) } &&
                       diagnostic_branch?(fallback) && statements(fallback).include?(node)
      else
        valid_branch = false
      end

      if !valid_branch
        issue(guard, 'Put validation warning() and fail() calls in the final else (or case default), with regular implementation in the valid branch')
        reported << guard
      elsif implementation_follows?(path.take(guard_index + 1))
        issue(guard, 'Keep the remaining implementation inside the valid branch; no implementation may follow this validation or its enclosing blocks within the class or defined type')
        reported << guard
      else
        terminal_guards << guard
      end
    end
    # Diagnostic fallbacks retain their final position even when several messages exceed the valid branch's size.
    reported | terminal_guards
  end

  # Measure code structure, not formatting or function names. A call or assignment is one statement;
  # nested bodies, resource attributes and collection entries contribute their own structural work.
  def branch_size(node, statement = true)
    m = ProjectLint::Model::M
    return 0 unless node.is_a?(m::Positioned)
    return 0 if node.is_a?(m::Nop)

    case node
    when m::BlockExpression
      node.statements.sum { |child| branch_size(child) }
    when m::IfExpression
      1 + branch_size(node.then_expr) + branch_size(node.else_expr)
    when m::CaseExpression
      1 + node.options.sum { |option| 1 + branch_size(option.then_expr) }
    when m::LambdaExpression
      1 + branch_size(node.body)
    else
      structural = [m::AbstractResource, m::ResourceBody, m::AbstractAttributeOperation, m::KeyedEntry, m::SelectorEntry]
      own = statement || structural.any? { |type| node.is_a?(type) } ? 1 : 0
      own += node.values.length if node.is_a?(m::LiteralList)
      own + node.enum_for(:_pcore_contents).sum { |child| branch_size(child, false) }
    end
  end

  # Compare individual elsif arms, not their accumulated size. An explicit nested if remains a nested code block.
  def following_size(node, positions, diagnostic_fallbacks)
    return 0 if diagnostic_fallbacks.include?(node)

    if node.is_a?(ProjectLint::Model::M::IfExpression) && positions.fetch([node.line, node.pos]).type == :ELSIF
      [branch_size(node.then_expr), following_size(node.else_expr, positions, diagnostic_fallbacks)].max
    else
      branch_size(node)
    end
  end

  def check
    validation_guards = check_validation_structure
    diagnostic_fallbacks = validation_guards.grep(ProjectLint::Model::M::IfExpression).filter_map do |guard|
      guard.else_expr if diagnostic_branch?(guard.else_expr)
    end
    positions = tokens.to_h { |token| [[token.line, token.column], token] }
    model.nodes.each do |node, _|
      next unless node.is_a?(ProjectLint::Model::M::IfExpression)
      next if validation_guards.include?(node)
      next unless branch_size(node.then_expr) < following_size(node.else_expr, positions, diagnostic_fallbacks)

      issue(node, 'Put the larger code branch first and keep shorter handling in the final else; preserve condition semantics and elsif priority')
    end
  end
end
