# frozen_string_literal: true

require_relative 'value'

module ProjectLint
  module Monitoring
    # Resolve transitive monitoring wrappers through the existing module resolver.
    module Wrappers
      def resource_names(resource)
        name = resource.type_name.value.delete_prefix('::')
        return [name] unless name == 'class'

        resource.bodies.filter_map { |body| body.title.value if body.title.is_a?(M::LiteralString) }
      end

      def included_names(node)
        return [] unless node.is_a?(M::CallNamedFunctionExpression)
        return [] unless %w[include contain require].include?(node.functor_expr.value)

        node.arguments.flat_map { |argument| literal_names(argument) }
      end

      def literal_names(node)
        return [node.value.delete_prefix('::')] if node.is_a?(M::LiteralString) || node.is_a?(M::QualifiedName)
        return node.values.flat_map { |value| literal_names(value) } if node.is_a?(M::LiteralList)

        []
      end

      def declaration_calls(name)
        declaration = @declarations[name] || Interfaces.find(name)
        return [] unless declaration&.body

        [declaration.body, *model.descendants(declaration.body)].flat_map do |child|
          child.is_a?(M::ResourceExpression) ? resource_names(child) : included_names(child)
        end
      end

      def wrapper?(name)
        @wrappers[name] = reaches_monitoring?(name) unless @wrappers.key?(name)
        @wrappers[name]
      end

      def reaches_monitoring?(name)
        pending = [name]
        visited = []
        until pending.empty?
          candidate = pending.shift
          return true if candidate == TARGET
          next if visited.include?(candidate)

          visited << candidate
          pending.concat(declaration_calls(candidate))
        end
        false
      end
    end
  end
end
