# frozen_string_literal: true

require 'puppet'
require 'puppet/pops'
require_relative 'parameter_order'

module ProjectLint
  # Use OpenVox's Puppet AST for structure and the lint lexer for comments and concrete whitespace.
  class Model
    M = Puppet::Pops::Model
    attr_reader :code, :program, :nodes

    def self.current
      code = PuppetLint::Data.manifest_lines.join("\n")
      @current = new(code, PuppetLint::Data.path) unless @current && @current.code == code
      @current
    end

    def initialize(code, path = 'example.pp')
      @code = code
      @program = Puppet::Pops::Parser::EvaluatingParser.new.parse_string(code, path)
      @nodes = []
      program._pcore_all_contents([]) { |node, parents| @nodes << [node, parents.dup] if node.is_a?(M::Positioned) }
    end

    def each_node(type = M::Positioned, &block)
      nodes.select { |node, _parents| node.is_a?(type) }.each(&block)
    end

    def resource_bodies(type)
      each_node(M::ResourceExpression).flat_map do |resource, parents|
        next [] unless resource.type_name.value == type

        resource.bodies.map { |body| [resource, body, parents] }
      end
    end

    def scope_of(parents)
      parents.reverse.find { |parent| parent.is_a?(M::NamedDefinition) || parent.is_a?(M::LambdaExpression) }
    end

    def named_type?(node, name, parameterized: false)
      return false if parameterized && !node.is_a?(M::AccessExpression)

      node = node.left_expr if node.is_a?(M::AccessExpression)
      node.is_a?(M::QualifiedReference) && node.cased_value == name
    end

    def declarations
      nodes.map(&:first).select { |node| node.is_a?(M::HostClassDefinition) || node.is_a?(M::ResourceTypeDefinition) }
    end

    def text(node)
      code.byteslice(node.offset, node.length)
    end

    def descendants(node)
      result = []
      node._pcore_all_contents([]) { |child, _| result << child if child.is_a?(M::Positioned) }
      result
    end

    def references(node)
      return [] unless node

      ([node] + descendants(node)).grep(M::VariableExpression).map { |variable| variable.expr.value }.uniq
    end

    def optional?(parameter)
      type = parameter.type_expr
      !parameter.value.nil? || named_type?(type, 'Optional', parameterized: true)
    end

    # Alphabetical order yields only to a real local default dependency.
    # Optional without a default stays required at call time.
    def parameter_order(declaration)
      ParameterOrder.new(self, declaration.parameters).ordered
    end
  end

  # Share node-position reporting, without ever including arbitrary source values in diagnostics.
  module ModelCheck
    # Native parser failures are ordinary plugin errors.
    # The separate Puppet validator provides the full syntax diagnostic.
    def run
      super
    rescue Puppet::ParseError => e
      notify(:error, message: 'Invalid Puppet syntax; run puppet parser validate', line: e.line || 1,
                     column: e.pos || 1, check: :syntax)
      @problems
    end

    def model
      Model.current
    end

    def issue(node, message, kind = :warning)
      notify(kind, message: message, line: node.line, column: node.pos)
    end
  end
end
