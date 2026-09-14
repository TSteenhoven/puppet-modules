# frozen_string_literal: true

require 'project_lint/ast'
require 'project_lint/module_resolver'

# Project-owned Puppet lint rules.
module ProjectLint
  # Native checks and their local analyses.
  module Checks
    # Validate statically resolvable public calls without guessing splatted attributes.
    module InterfaceCalls
      include AstCheck

      def check
        @resolver = ModuleResolver.new
        @declarations = ast.declarations.to_h { |declaration| [declaration.name, declaration] }
        ast.each_node(Ast::M::ResourceExpression) do |resource, _parents|
          resource.bodies.each { |body| check_call(resource, body) }
        end
      end

      def called_declaration(resource, body)
        name = resource.type_name.value
        name = body.title.value if name == 'class' && body.title.is_a?(Ast::M::LiteralString)
        @declarations[name] || @resolver.find(name)
      end

      def check_call(resource, body)
        declaration = called_declaration(resource, body)
        return unless declaration
        # Splatted attributes require catalog validation; Optional without a default remains required.
        return unless body.operations.all?(Ast::M::AttributeOperation)

        missing = required_parameters(declaration) - body.operations.map(&:attribute_name)
        return if missing.empty?

        issue(body.title, "Public interface call omits required parameters: #{missing.join(', ')}")
      end

      def required_parameters(declaration)
        declaration.parameters.select { |parameter| parameter.value.nil? }.map(&:name)
      end
    end
    PuppetLint.new_check(:project_interface_calls) { include InterfaceCalls }
  end
end
