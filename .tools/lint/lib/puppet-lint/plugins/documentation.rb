require_relative '../../model'

PuppetLint.new_check(:project_documentation) do
  include ProjectLint::ModelCheck

  def check
    model.declarations.each do |declaration|
      comments = model.comments_before(declaration)
      text = comments.map(&:last)
      issue(declaration, 'Document the declaration with one non-empty @summary') unless text.count { |line| line.match?(/^@summary\s+\S/) } == 1
      issue(declaration, 'Document the declaration with @api public or @api private') unless text.count { |line| line.match?(/^@api (?:public|private)$/) } == 1
      issue(declaration, 'Provide a Puppet Strings @example') unless text.any? { |line| line.match?(/^@example\s+\S/) }
      documented = text.filter_map { |line| line[/^@param\s+(?:\[[^\]]+\]\s+)?(\w+)/, 1] }
      issue(declaration, 'Document every parameter exactly once, in declaration order') unless documented == declaration.parameters.map(&:name)
      text.each_with_index do |line, index|
        next unless line.start_with?('@param ')
        next if line.match?(/^@param\s+\w+\s+\S/) || (text[index + 1] && text[index + 1].match?(/^\s+\S/))

        issue(declaration, 'Give each @param a description of its contract and default meaning')
      end
      example = false
      text.each_with_index do |line, index|
        example = line.start_with?('@example') if line.start_with?('@')
        previous = index.positive? ? text[index - 1] : nil
        next if example || !previous || line.strip.empty? || previous.strip.empty?
        next if line.lstrip.start_with?('@', '-', '*', '|') || previous.lstrip.start_with?('@', '-', '*', '|')
        next unless line[/\A */] == previous[/\A */]
        next if previous.match?(/[.!?:][`'"]*\z/)

        notify(:warning, message: 'Keep each Puppet Strings prose sentence on one physical line', line: comments[index].first, column: 1)
      end
    end
  end
end

PuppetLint.new_check(:project_suppressions) do
  def check
    tokens.select { |token| [:COMMENT, :MLCOMMENT, :SLASH_COMMENT].include?(token.type) }.each do |token|
      # Match actual control comments; mentioning a directive in prose or a string does not suppress a check.
      next unless token.value.strip.match?(/\Alint:(?:ignore|endignore)\b/)
      controls = token.value.strip.split.take_while { |word| word.start_with?('lint:') }
      next if controls == ['lint:endignore']
      allowed = %w[lint:ignore:140chars lint:ignore:puppet_url_without_modules]
      next if controls.any? && controls.all? { |control| allowed.include?(control) }

      notify(:error, message: 'Only targeted 140chars and puppet_url_without_modules suppressions are allowed; fix other lint violations', line: token.line, column: token.column)
    end
  end
end
