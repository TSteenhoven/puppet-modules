require_relative '../../model'

PuppetLint.new_check(:project_resource_references) do
  include ProjectLint::ModelCheck

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

  def inspect_references(references)
    titles = references.flat_map(&:keys)
    literal = titles.all? { |title| literal_title?(title) }
    unordered = literal && titles.map(&:value) != titles.map(&:value).sort
    return unless references.length > 1 || unordered

    first = @positions.fetch([references.first.line, references.first.pos])
    opening = first.next_code_token
    closing = @closings.fetch(@positions.fetch([references.last.line, references.last.pos]).next_code_token)
    span = @source_tokens[@source_tokens.index(opening)..@source_tokens.index(closing)]
    commented = span.any? { |token| [:COMMENT, :SLASH_COMMENT, :MLCOMMENT].include?(token.type) }
    title_tokens = literal ? titles.map { |title| @positions.fetch([title.line, title.pos]) } : []
    # Heredocs have detached bodies; only ordinary literal tokens can be moved as one title.
    fixable = literal && !commented && title_tokens.all? { |token| [:SSTRING, :STRING, :NAME].include?(token.type) }
    message = if references.length > 1
                'Merge adjacent references of the same resource type and sort their titles alphabetically'
              else
                'Sort resource reference titles alphabetically'
              end
    message += ' [review] Preserve comments and resolve dynamic titles manually' unless fixable
    @fixes << { opening: opening, closing: closing, titles: titles.zip(title_tokens), fixable: fixable, merged: references.length > 1 }
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
    model.nodes.each do |node, _|
      next unless node.is_a?(m::LiteralList)

      # Only sibling array entries can merge. Function arguments, nested arrays and relationship operands have separate meanings.
      node.values.chunk { |value| reference?(value) ? value.left_expr.value : nil }.each do |type, group|
        next unless type

        inspect_references(group)
        # AST equality ignores source positions; track occurrences rather than structurally equal expressions.
        group.each { |reference| handled[reference.object_id] = true }
      end
    end
    model.nodes.each do |node, _|
      inspect_references([node]) if reference?(node) && !handled.key?(node.object_id)
    end
  end

  def fix(problem)
    edit = @fixes.fetch(problem[:edit])
    raise PuppetLint::NoFix unless edit[:fixable]

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
    closing = edit[:closing]
    interior = tokens[(tokens.index(opening) + 1)...tokens.index(closing)]
    multiline = opening.line != closing.line
    indent = manifest_lines[opening.line - 1][/\A[ \t]*/]
    separator = multiline ? ",\n#{indent}  " : ', '
    # Reuse title tokens, preserving spelling, escapes, duplicates and fixes applied by other plugins.
    replacement = []
    replacement.concat(PuppetLint::Lexer.new.tokenise("\n#{indent}  ")) if multiline
    ordered.each_with_index do |token, index|
      replacement.concat(PuppetLint::Lexer.new.tokenise(separator)) if index.positive?
      replacement << token
    end
    replacement.concat(PuppetLint::Lexer.new.tokenise(",\n#{indent}")) if multiline
    interior.each { |token| remove_token(token) }
    index = tokens.index(opening) + 1
    replacement.each_with_index { |token, offset| add_token(index + offset, token) }
  end
end
