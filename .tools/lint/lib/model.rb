require 'puppet'
require 'puppet/pops'

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
      !parameter.value.nil? || (type.is_a?(M::AccessExpression) && type.left_expr.is_a?(M::QualifiedReference) && type.left_expr.cased_value == 'Optional')
    end

    # Alphabetical order yields only to a real local default dependency; Optional without a default stays required at call time.
    def parameter_order(declaration)
      parameters = declaration.parameters
      by_name = parameters.to_h { |parameter| [parameter.name, parameter] }
      ordered = []
      visiting = []
      visit = lambda do |parameter|
        return if ordered.include?(parameter)
        raise 'Cyclic parameter defaults' if visiting.include?(parameter)

        visiting << parameter
        references(parameter.value).select { |name| by_name.key?(name) }.sort.each { |name| visit.call(by_name.fetch(name)) }
        visiting.pop
        ordered << parameter
      end
      parameters.sort_by { |parameter| [optional?(parameter) ? 1 : 0, parameter.name] }.each { |parameter| visit.call(parameter) }
      ordered
    end
  end

  # Share node-position reporting, without ever including arbitrary source values in diagnostics.
  module ModelCheck
    # Native parser failures are ordinary plugin errors; the separate Puppet validator provides the full syntax diagnostic.
    def run
      super
    rescue Puppet::ParseError => error
      notify(:error, message: 'Invalid Puppet syntax; run puppet parser validate', line: error.line || 1, column: error.pos || 1, check: :syntax)
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
