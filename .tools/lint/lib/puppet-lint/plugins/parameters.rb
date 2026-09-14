require_relative '../../model'
require_relative '../../token_helpers'

PuppetLint.new_check(:project_parameter_order) do
  include ProjectLint::ModelCheck

  def check
    model.declarations.each do |declaration|
      expected = model.parameter_order(declaration)
      if declaration.parameters != expected
        issue(declaration, 'Put mandatory parameters first, then optional parameters; sort each group alphabetically subject to local default dependencies')
      end
      positions = declaration.parameters.each_with_index.to_h { |parameter, index| [parameter.name, index] }
      declaration.parameters.each do |parameter|
        model.references(parameter.value).each do |dependency|
          next unless positions.key?(dependency)
          issue(parameter, 'A local default refers to a parameter that must be declared earlier') if positions[dependency] >= positions.fetch(parameter.name)
        end
      end
      # A comment is required only for a parameter moved ahead of its ordinary alphabetical position.
      ordinary = declaration.parameters.sort_by { |parameter| [model.optional?(parameter) ? 1 : 0, parameter.name] }
      expected.each do |parameter|
        next unless expected.index(parameter) < ordinary.index(parameter)
        dependents = declaration.parameters.select { |other| model.references(other.value).include?(parameter.name) }
        next if dependents.empty?

        comments = tokens.select { |token| token.type == :COMMENT && token.line == parameter.line }
        unless comments.any? { |comment| dependents.any? { |dependent| comment.value.include?("$#{dependent.name}") } }
          issue(parameter, 'Explain the necessary default dependency in a trailing comment naming the dependent parameter')
        end
      end
    end
  end
end

PuppetLint.new_check(:project_parameter_alignment) do
  include ProjectLint::ModelCheck
  include ProjectLint::TokenHelpers

  def report_alignment(parameter, message, block)
    notify(:warning, message: message, line: parameter.line, column: parameter.column, edit: block)
  end

  def check
    # Retain original token anchors across the native detection and fix phases.
    @blocks ||= model.declarations.filter_map do |declaration|
      parameters = declaration.parameters
      next if parameters.empty? || parameters.any? { |parameter| parameter.type_expr.nil? }

      positions = tokens.to_h { |token| [[token.line, token.column], token] }
      parameters.map do |parameter|
        variable = positions.fetch([parameter.line, parameter.pos])
        equals = parameter.value ? variable.next_code_token : nil
        { variable: variable, type_start: positions.fetch([parameter.type_expr.line, parameter.type_expr.pos]),
          type_end: variable.prev_code_token, equals: equals }
      end
    end
    @blocks.each_with_index do |entries, block|
      name_column, equals_column = alignment_columns(entries)
      entries.each do |entry|
        variable = entry[:variable]
        if line_prefix(variable).length + 1 != name_column
          report_alignment(variable, 'Align parameter names after the widest type across the complete parameter block', block)
        end
        equals = entry[:equals]
        next unless equals

        if equals.type != :EQUALS || line_prefix(equals).length + 1 != equals_column
          report_alignment(variable, 'Align parameter equals signs across the complete parameter block', block)
        elsif code_after(equals).line == equals.line && line_prefix(code_after(equals)).length + 1 != equals_column + 2
          report_alignment(variable, 'Use one space between the aligned equals sign and a same-line default', block)
        end
      end
    end
  end

  def alignment_columns(block)
    name = block.map { |entry| line_prefix(entry[:type_end]).length + entry[:type_end].to_manifest.length + 2 }.max
    [name, name + block.map { |entry| entry[:variable].to_manifest.length }.max + 1]
  end

  def fix_problems
    return super if @problems.any? { |problem| problem[:check] == :syntax }

    # Upstream quote/tab fixes and project comma spacing can change type widths
    # even in a previously aligned block. Refresh this check on its saved anchors;
    # native run still applies lint:ignore, and native fix_problems calls fix(problem).
    @problems = []
    run
    super
  end

  def fix(problem)
    block = @blocks.fetch(problem[:edit])
    # Separate parameter lines provide stable columns. Inline declarations with
    # multiple parameters and comments inside alignment gaps need manual layout.
    raise PuppetLint::NoFix if block.length > 1 && block.any? { |entry| !line_prefix(entry[:type_start]).match?(/\A[ \t]*\z/) }
    raise PuppetLint::NoFix if ignored_span?(block.first[:type_start], block.last[:variable])
    block.each do |entry|
      raise PuppetLint::NoFix unless whitespace_gap?(entry[:type_end], entry[:variable])
      equals = entry[:equals]
      next unless equals

      raise PuppetLint::NoFix unless equals.type == :EQUALS && whitespace_gap?(entry[:variable], equals)
      following = code_after(equals)
      if following.line == equals.line
        raise PuppetLint::NoFix unless whitespace_gap?(equals, following)
      end
    end

    name_column, equals_column = alignment_columns(block)
    block.each do |entry|
      type_end = entry[:type_end]
      variable = entry[:variable]
      width = name_column - line_prefix(type_end).length - type_end.to_manifest.length - 1
      set_whitespace(type_end, variable, width)
      equals = entry[:equals]
      next unless equals

      set_whitespace(variable, equals, equals_column - name_column - variable.to_manifest.length)
      following = code_after(equals)
      set_whitespace(equals, following, 1) if following.line == equals.line
    end
  end
end
