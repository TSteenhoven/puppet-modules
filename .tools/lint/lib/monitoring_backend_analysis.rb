# frozen_string_literal: true

require_relative 'variable_dependencies'
require_relative 'monitoring/wrappers'
require_relative 'monitoring/parameters'
require_relative 'monitoring/bindings'
require_relative 'monitoring/branches'
require_relative 'monitoring/expressions'

module ProjectLint
  # Track backend-derived decisions without executing Puppet or inferring intent from names.
  class MonitoringBackendAnalysis
    include VariableDependencies
    include Monitoring::Wrappers
    include Monitoring::Parameters
    include Monitoring::Bindings
    include Monitoring::Branches
    include Monitoring::Expressions

    M = Model::M
    HANDLERS = {
      M::VariableExpression => :evaluate_variable, M::LiteralString => :evaluate_literal,
      M::ParenthesizedExpression => :evaluate_parentheses,
      M::HostClassDefinition => :evaluate_declaration, M::ResourceTypeDefinition => :evaluate_declaration,
      M::FunctionDefinition => :evaluate_declaration, M::NodeDefinition => :evaluate_node,
      M::LambdaExpression => :evaluate_lambda, M::BlockExpression => :evaluate_block,
      M::AssignmentExpression => :evaluate_assignment, M::IfExpression => :evaluate_if,
      M::CaseExpression => :evaluate_selection, M::SelectorExpression => :evaluate_selection,
      M::ResourceExpression => :evaluate_resource
    }.freeze
    attr_reader :model, :warnings

    def initialize(model)
      @model = model
      @warnings = []
      @declarations = model.declarations.to_h { |declaration| [declaration.name, declaration] }
      @wrappers = {}
    end

    def evaluate(node, environment = {}, guards = [], owner = nil)
      return Monitoring::Value.new(false, nil, []) unless node.is_a?(M::Positioned)

      handler = HANDLERS.find { |type, _method| node.is_a?(type) }&.last || :evaluate_children
      public_send(handler, node, environment, guards, owner)
    end
  end
end
