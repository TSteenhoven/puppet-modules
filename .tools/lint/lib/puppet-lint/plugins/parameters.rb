require_relative '../../model'

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

  def check
    model.declarations.each do |declaration|
      parameters = declaration.parameters
      next if parameters.empty? || parameters.any? { |parameter| parameter.type_expr.nil? }

      # Multiline type closing lines participate in the same name column as single-line types.
      type_ends = parameters.map do |parameter|
        type = parameter.type_expr
        last = model.code.byteslice(0, type.offset + type.length).lines.last.chomp
        last.length + 2
      end
      name_column = type_ends.max
      equals_column = name_column + parameters.map { |parameter| parameter.name.length + 1 }.max + 1
      parameters.each do |parameter|
        issue(parameter, 'Align parameter names after the widest type across the complete parameter block') unless parameter.pos == name_column
        next unless parameter.value

        # Use the concrete EQUALS token after this parameter, avoiding operators inside nested defaults.
        variable = tokens.find { |token| token.type == :VARIABLE && token.line == parameter.line && token.column == parameter.pos }
        equals = variable&.next_code_token
        if !equals || equals.type != :EQUALS || equals.column != equals_column
          issue(parameter, 'Align parameter equals signs across the complete parameter block')
        elsif equals.next_code_token.line == equals.line && equals.next_code_token.column != equals_column + 2
          issue(parameter, 'Use one space between the aligned equals sign and a same-line default')
        end
      end
    end
  end
end
