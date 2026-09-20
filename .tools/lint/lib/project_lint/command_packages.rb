# frozen_string_literal: true

require 'project_lint/resource_values'

module ProjectLint
  # Recognize a deliberately small set of executable entrypoints, without parsing shell programs.
  class CommandPackages
    # Explicit Debian/Ubuntu providers, not a command-name-to-package heuristic.
    PROVIDERS = { 'bash' => 'bash', 'cmp' => 'diffutils', 'curl' => 'curl', 'jq' => 'jq',
                  'rsync' => 'rsync', 'tar' => 'tar', 'unzip' => 'unzip', 'wget' => 'wget' }.freeze

    def initialize(ast)
      @values = ResourceValues.new(ast)
    end

    def resolve(node, seen = [])
      return if seen.any? { |item| item.equal?(node) }
      return resolve(@values.local_value(node), seen + [node]) if node.is_a?(Ast::M::VariableExpression)

      node
    end

    def commands(node, guard: false)
      node = resolve(node)
      return Array(executable(node)) unless node.is_a?(Ast::M::LiteralList)
      return node.values.flat_map { |value| commands(value) } if guard

      Array(executable(resolve(node.values.first), array: true))
    end

    def text(node)
      case node
      when Ast::M::LiteralString then node.value
      when Ast::M::ConcatenatedString
        first = node.segments.first
        first.value if first.is_a?(Ast::M::LiteralString)
      end
    end

    def executable(node, array: false)
      value = text(node)
      return unless executable_text?(node, value, array)

      word = array ? value : value[%r{\A\s*([a-zA-Z0-9_/.+-]+)(?=\s|\z)}, 1]
      return unless word && system_command?(word)

      name = File.basename(word)
      name if PROVIDERS.key?(name)
    end

    def executable_text?(node, value, array)
      return false unless value
      # A fallback may intentionally tolerate a missing tool. Shell bodies remain manual review.
      return false if !array && value.match?(/\|\||[\n`]/)

      !node.is_a?(Ast::M::ConcatenatedString) || value.match?(/\s\S*\z/)
    end

    def system_command?(word)
      !word.include?('/') || word.match?(%r{\A/(?:usr/)?bin/[^/]+\z})
    end

    def optional?(name, onlyif)
      node = resolve(onlyif)
      guards = node.is_a?(Ast::M::LiteralList) ? node.values : [node]
      guards.any? do |guard|
        value = presence_test(guard)
        next false unless value

        value.match?(%r{\A\s*(?:(?:/usr/bin/|/bin/)?test -x |\[ -x )/(?:usr/)?bin/#{name}(?: \])?\s*\z}) ||
          value.match?(%r{\A\s*command -v (?:/(?:usr/)?bin/)?#{name}(?:\s+>/dev/null(?:\s+2>&1)?)?\s*\z})
      end
    end

    def presence_test(node)
      node = resolve(node)
      return text(node) unless node.is_a?(Ast::M::LiteralList)

      words = node.values.map { |word| text(resolve(word)) }
      words.join(' ') if words.none?(&:nil?)
    end
  end
end
