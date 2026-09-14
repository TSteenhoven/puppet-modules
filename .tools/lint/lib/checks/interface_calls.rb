# frozen_string_literal: true

require_relative '../model'

module ProjectLint
  # Validate statically resolvable public calls without guessing splatted attributes.
  module InterfaceCallsCheck
    include ModelCheck

    def check
      @declarations = model.declarations.to_h { |declaration| [declaration.name, declaration] }
      model.each_node(Model::M::ResourceExpression) do |resource, _parents|
        resource.bodies.each { |body| check_call(resource, body) }
      end
    end

    def called_declaration(resource, body)
      name = resource.type_name.value
      name = body.title.value if name == 'class' && body.title.is_a?(Model::M::LiteralString)
      @declarations[name] || Interfaces.find(name)
    end

    def check_call(resource, body)
      declaration = called_declaration(resource, body)
      return unless declaration
      # Splatted attributes require catalog validation; Optional without a default remains required.
      return unless body.operations.all?(Model::M::AttributeOperation)

      missing = required_parameters(declaration) - body.operations.map(&:attribute_name)
      return if missing.empty?

      issue(body.title, "Public interface call omits required parameters: #{missing.join(', ')}")
    end

    def required_parameters(declaration)
      declaration.parameters.select { |parameter| parameter.value.nil? }.map(&:name)
    end
  end
end
