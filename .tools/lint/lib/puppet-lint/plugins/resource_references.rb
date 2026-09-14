require_relative '../../model'
require_relative '../../token_helpers'

PuppetLint.new_check(:project_resource_references) do
  include ProjectLint::ModelCheck
  include ProjectLint::TokenHelpers

  # A multi-title reference evaluates to an array. Only relationship consumers
  # flatten those arrays and ignore title ordering; ordinary values can observe both.
  def relationship_context?(node, parents)
    m = ProjectLint::Model::M
    child = node
    parents.reverse_each do |parent|
      if parent.is_a?(m::LiteralList) || parent.is_a?(m::ParenthesizedExpression)
        child = parent
        next
      end
      if parent.is_a?(m::RelationshipExpression)
        containers = [m::Program, m::BlockExpression, m::HostClassDefinition, m::ResourceTypeDefinition,
                      m::NodeDefinition, m::IfExpression, m::RelationshipExpression, m::ParenthesizedExpression]
        return parents.take(parents.index(parent)).all? { |ancestor| containers.any? { |type| ancestor.is_a?(type) } }
      end
      return parent.is_a?(m::AttributeOperation) && parent.value_expr.equal?(child) &&
             %w[require before notify subscribe].include?(parent.attribute_name)
    end
    false
  end

  def reference?(node)
    m = ProjectLint::Model::M
    return false unless node.is_a?(m::AccessExpression) && node.left_expr.is_a?(m::QualifiedReference)

    name = node.left_expr.value
    # Puppet uses access expressions for both resource references and parameterized data types.
    return false if name != 'class' && Puppet::Pops::Types::TypeParser.type_map.key?(name)

    !@type_names.include?(name)
  end

  def literal_title?(node)
    node.is_a?(ProjectLint::Model::M::LiteralString) || node.is_a?(ProjectLint::Model::M::QualifiedName)
  end

  def inspect_references(references, relationship, wrapper = nil, safe_merge: true)
    titles = references.flat_map(&:keys)
    literal = titles.all? { |title| literal_title?(title) }
    unordered = literal && titles.map(&:value) != titles.map(&:value).sort
    change_titles = references.length > 1 || unordered
    return unless change_titles || wrapper

    occurrences = references.map do |reference|
      start = @positions.fetch([reference.line, reference.pos])
      [start, @closings.fetch(start.next_code_token)]
    end
    first = occurrences.first.first
    opening = first.next_code_token
    closing = occurrences.last.last
    outer_opening = @positions.fetch([wrapper.line, wrapper.pos]) if wrapper
    outer_closing = @closings.fetch(outer_opening) if wrapper
    span_first = outer_opening || first
    span_last = outer_closing || closing
    if references.length > 1 && !wrapper
      # A trailing comment can belong to a removed entry, including after its comma.
      trailing = @source_tokens.drop(@source_tokens.index(closing) + 1).take_while do |token|
        token.type == :COMMA || PuppetLint::Data.formatting_tokens.include?(token.type)
      end
      span_last = trailing.last || closing
    end
    span = @source_tokens[@source_tokens.index(span_first)..@source_tokens.index(span_last)]
    commented = span.any? { |token| [:COMMENT, :SLASH_COMMENT, :MLCOMMENT].include?(token.type) }
    title_tokens = literal ? titles.map { |title| @positions.fetch([title.line, title.pos]) } : []
    # Heredocs have detached bodies; only ordinary literal tokens can be moved as one title.
    movable_titles = literal && title_tokens.all? { |token| [:SSTRING, :STRING, :NAME].include?(token.type) }
    fixable = relationship && safe_merge && !commented && !ignored_span?(span_first, span_last) &&
              !span.any? { |token| token.type == :HEREDOC_OPEN } && (!change_titles || movable_titles)
    message = if references.length > 1
                'Merge references of the same resource type within the array and sort their titles alphabetically'
              elsif unordered
                'Sort resource reference titles alphabetically'
              else
                'Remove the outer array around a single resource reference'
              end
    message += '; remove the outer array around the resulting single reference' if wrapper && change_titles
    message += ' [review] Verify relationship context, array shape, title order and comments before changing this expression' unless fixable
    @fixes << { first: first, opening: opening, closing: closing, occurrences: occurrences,
                outer_opening: outer_opening, outer_closing: outer_closing,
                titles: titles.zip(title_tokens), fixable: fixable, merged: references.length > 1, change_titles: change_titles }
    notify(:warning, message: message, line: first.line, column: first.column, edit: @fixes.length - 1)
  end

  def check
    @source_tokens = tokens
    @positions = @source_tokens.to_h { |token| [[token.line, token.column], token] }
    @closings = {}
    openings = []
    @source_tokens.each do |token|
      openings << token if token.type == :LBRACK
      @closings[openings.pop] = token if token.type == :RBRACK && openings.any?
    end
    @fixes = []
    m = ProjectLint::Model::M
    @type_names = model.nodes.filter_map { |node, _| node.name.downcase if node.is_a?(m::TypeAlias) || node.is_a?(m::TypeDefinition) }
    handled = {}
    model.nodes.each do |node, parents|
      next unless node.is_a?(m::LiteralList)

      # Group siblings across the entire array without crossing into nested arrays or other operands.
      node.values.each_with_index.group_by { |value, _| reference?(value) ? value.left_expr.value : nil }.each do |type, entries|
        next unless type

        group = entries.map(&:first)
        # Moving literal references past another literal reference cannot change expression evaluation.
        # Unresolved entries may execute code or contain further references, so leave those crossings for review.
        between = node.values[entries.first.last..entries.last.last]
        safe_merge = group.length == 1 || between.all? { |value| reference?(value) && value.keys.all? { |title| literal_title?(title) } }
        relationship = relationship_context?(node, parents)
        parent = parents.reverse.find { |ancestor| !ancestor.is_a?(m::ParenthesizedExpression) }
        # Unwrap only the complete operand/value. Removing nested wrappers could expose new groups on a later run.
        wrapper = relationship && group.length == node.values.length && !parent.is_a?(m::LiteralList) ? node : nil
        inspect_references(group, relationship, wrapper, safe_merge: safe_merge)
        # AST equality ignores source positions; track occurrences rather than structurally equal expressions.
        group.each { |reference| handled[reference.object_id] = true }
      end
    end
    model.nodes.each do |node, parents|
      inspect_references([node], relationship_context?(node, parents)) if reference?(node) && !handled.key?(node.object_id)
    end
  end

  def unwrap_reference(edit)
    first = edit[:first]
    prefix = line_prefix(first)
    indent = line_prefix(edit[:outer_opening])[/\A[ \t]*/]
    shift = prefix.match?(/\A[ \t]*\z/) ? [prefix.length - indent.length, 0].max : 0
    if shift.positive?
      # Adjust code indentation only; whitespace inside string tokens remains literal content.
      token_span(first, edit[:closing]).each_cons(2) do |previous, token|
        next unless previous.type == :NEWLINE && [:INDENT, :WHITESPACE].include?(token.type)

        token.value = token.value.sub(/\A {1,#{shift}}/, '')
      end
    end
    token_span(edit[:outer_opening], first)[0...-1].each { |token| remove_token(token) }
    token_span(edit[:closing], edit[:outer_closing])[1..].each { |token| remove_token(token) }
  end

  def fix(problem)
    edit = @fixes.fetch(problem[:edit])
    raise PuppetLint::NoFix unless edit[:fixable]

    # Resolve each removal separately before editing; spans of interleaved type groups overlap.
    removals = edit[:occurrences].drop(1).map do |first, last|
      comma = first.prev_code_token
      raise PuppetLint::NoFix unless comma&.type == :COMMA

      token_span(comma, last)
    end
    unwrap_reference(edit) if edit[:outer_opening]
    return unless edit[:change_titles]

    ordered = edit[:titles].each_with_index.sort_by { |(title, _), index| [title.value, index] }.map { |(_, token), _| token }
    original = edit[:titles].map(&:last)
    unless edit[:merged]
      # Keep each whitespace slot intact, moving token objects so other standard fixes still target the right strings.
      slots = original.map { |token| tokens.index(token) }
      original.each { |token| remove_token(token) }
      slots.zip(ordered).each { |index, token| add_token(index, token) }
      return
    end

    opening = edit[:opening]
    closing = edit[:occurrences].first.last
    interior = tokens[(tokens.index(opening) + 1)...tokens.index(closing)]
    multiline = opening.line != (edit[:outer_opening] ? edit[:closing] : closing).line
    indent = line_prefix(opening)[/\A[ \t]*/]
    separator = multiline ? ",\n#{indent}  " : ', '
    # Reuse title tokens, preserving spelling, escapes, duplicates and fixes applied by other plugins.
    replacement = []
    replacement.concat(PuppetLint::Lexer.new.tokenise("\n#{indent}  ")) if multiline
    ordered.each_with_index do |token, index|
      replacement.concat(PuppetLint::Lexer.new.tokenise(separator)) if index.positive?
      replacement << token
    end
    replacement.concat(PuppetLint::Lexer.new.tokenise(",\n#{indent}")) if multiline
    (interior + removals.flatten).each { |token| remove_token(token) }
    index = tokens.index(opening) + 1
    replacement.each_with_index { |token, offset| add_token(index + offset, token) }
  end
end
