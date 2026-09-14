# frozen_string_literal: true

require 'puppet'
require 'puppet/pops'

module ProjectLint
  # Use OpenVox's Puppet AST for structure and the lint lexer for comments and concrete whitespace.
  class Ast
    M = Puppet::Pops::Model
    attr_reader :program, :nodes

    def self.current
      lines = PuppetLint::Data.manifest_lines
      unless @lines.equal?(lines)
        @current = new(lines.join("\n"), PuppetLint::Data.path)
        @lines = lines
      end
      @current
    end

    def initialize(code, path = 'example.pp')
      @program = Puppet::Pops::Parser::EvaluatingParser.new.parse_string(code, path)
      @nodes = []
      program._pcore_all_contents([]) do |node, parents|
        @nodes << [node, parents.dup] if node.is_a?(Ast::M::Positioned)
      end
    end

    def each_node(type = Ast::M::Positioned, &block)
      nodes.select { |node, _parents| node.is_a?(type) }.each(&block)
    end

    def resource_bodies(type)
      each_node(Ast::M::ResourceExpression).flat_map do |resource, parents|
        next [] unless resource.type_name.value == type

        resource.bodies.map { |body| [resource, body, parents] }
      end
    end

    def scope_of(parents)
      parents.reverse.find { |parent| parent.is_a?(Ast::M::NamedDefinition) || parent.is_a?(Ast::M::LambdaExpression) }
    end

    def named_type?(node, name, parameterized: false)
      return false if parameterized && !node.is_a?(Ast::M::AccessExpression)

      node = node.left_expr if node.is_a?(Ast::M::AccessExpression)
      node.is_a?(Ast::M::QualifiedReference) && node.cased_value == name
    end

    def declarations
      nodes.map(&:first).select { |node| node.is_a?(Ast::M::HostClassDefinition) || node.is_a?(Ast::M::ResourceTypeDefinition) }
    end

    def descendants(node)
      result = []
      node._pcore_all_contents([]) { |child, _| result << child if child.is_a?(Ast::M::Positioned) }
      result
    end

    def references(node)
      return [] unless node

      ([node] + descendants(node)).grep(Ast::M::VariableExpression).map { |variable| variable.expr.value }.uniq
    end

    def optional?(parameter)
      type = parameter.type_expr
      !parameter.value.nil? || named_type?(type, 'Optional', parameterized: true)
    end
  end

  # Share node-position reporting, without ever including arbitrary source values in diagnostics.
  module AstCheck
    # Native parser failures are ordinary plugin errors.
    # The separate Puppet validator provides the full syntax diagnostic.
    def run
      super
    rescue Puppet::ParseError => e
      notify(:error, message: 'Invalid Puppet syntax; run puppet parser validate', line: e.line || 1,
                     column: e.pos || 1, check: :syntax)
      @problems
    end

    def ast
      Ast.current
    end

    def issue(node, message, kind = :warning)
      notify(kind, message: message, line: node.line, column: node.pos)
    end
  end
end
