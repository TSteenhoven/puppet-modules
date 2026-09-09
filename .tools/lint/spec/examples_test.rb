require_relative 'test_helper'

class ExamplesTest < Minitest::Test
  # Extract documentation examples only for regression tests; normal manifest discovery remains owned by puppet-lint.
  def examples
    result = []
    project_files('./**/*.pp').each do |path|
      block = nil
      PuppetLint::Lexer.new.tokenise(File.read(path)).select { |token| token.type == :COMMENT }.each do |token|
        # Outer control comments do not end a Strings example; embedded Puppet directives remain in its code.
        next if token.value.match?(/\A lint:(?:ignore:140chars|endignore)\b/)

        if token.value.match?(/^\s*@example\b/)
          result << block if block
          block = { path: path, line: token.line, code: String.new }
        elsif block && token.value.start_with?('   ')
          block[:code] << "\n" while block[:line] + block[:code].lines.length < token.line - 1
          block[:code] << token.value.delete_prefix('   ') + "\n"
        elsif block
          result << block
          block = nil
        end
      end
      result << block if block
    end
    # The hidden tooling directory is explicit because Ruby's ordinary recursive glob skips dot directories.
    (project_files('./**/*.md') + project_files('./.tools/**/*.md')).each do |path|
      block = nil
      fence = nil
      File.readlines(path).each_with_index do |line, index|
        if fence
          if line.match?(/\A {0,3}#{Regexp.escape(fence[0])}{#{fence.length},}[ \t]*\r?\n?\z/)
            result << block if block
            block = fence = nil
          elsif block
            block[:code] << line
          end
        elsif (opening = line.match(/\A {0,3}(`{3,}|~{3,})[ \t]*([^\r\n]*)/))
          fence = opening[1]
          block = { path: path, line: index + 1, code: String.new } if %w[puppet pp].include?(opening[2].split.first)
        end
      end
      assert_nil block, "Unclosed Puppet fence in #{path}"
    end
    result.reject { |example| example[:code].empty? }
  end

  def test_documentation_examples_pass_the_same_lint_checks_and_native_parser
    snippets = examples
    refute_empty snippets
    Dir.mktmpdir('puppet-examples-') do |directory|
      files = snippets.each_with_index.map do |example, index|
        lint = PuppetLint.new
        lint.path = example[:path]
        lint.code = example[:code]
        lint.run
        problems = lint.problems.reject { |finding| finding[:kind] == :ignored }
        assert_empty problems, "#{example[:path]}:#{example[:line]}: #{problems.map { |finding| finding[:check] }.join(', ')}"
        path = File.join(directory, "example_#{index}.pp")
        File.write(path, example[:code])
        path
      end
      _, errors, status = Open3.capture3(Gem.bin_path('openvox', 'puppet'), 'parser', 'validate', *files)
      assert status.success?, errors
    end
  end

  def test_discovers_puppet_examples_in_hidden_tooling_documentation
    Dir.mktmpdir('example_discovery_', File.join(ProjectLint::ROOT, '.tools')) do |directory|
      path = File.join(directory, 'README.md')
      code = "$values = concat([1], [2])\n"
      File.write(path, "```puppet\n#{code}```\n")
      snippet = examples.find { |example| File.expand_path(example[:path]) == path }
      refute_nil snippet, 'Puppet examples in .tools must remain part of documentation validation'
      assert_equal code, snippet.fetch(:code)
    end
  end
end
