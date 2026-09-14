# frozen_string_literal: true

require 'erb'
require 'ripper'
require 'project_lint/module_resolver'
require 'project_lint/variable_dependencies'

module ProjectLint
  # Count reads of one assigned class check across Puppet scopes and static ERB sources.
  class ClassCheckReads
    include VariableDependencies

    attr_reader :assignment, :ast

    def initialize(check, declaration, nodes, parents, resolver)
      @check = check
      @ast = check.ast
      @resolver = resolver
      @declaration = declaration
      @nodes = nodes
      @ancestors = parents.dup
      @ancestors.pop while @ancestors.last.is_a?(Ast::M::ParenthesizedExpression) || @ancestors.last.is_a?(Ast::M::NotExpression)
      @assignment = @ancestors.last
    end

    def assigned_variable?
      assignment.is_a?(Ast::M::AssignmentExpression) && assignment.left_expr.is_a?(Ast::M::VariableExpression)
    end

    def name
      assignment.left_expr.expr.value
    end

    def scope
      @ancestors.reverse.find { |parent| parent.is_a?(Ast::M::LambdaExpression) } || @declaration
    end

    def qualified_name
      "#{@declaration.name}::#{name}" if scope.equal?(@declaration) && @declaration.is_a?(Ast::M::HostClassDefinition)
    end

    def local_reads
      names = [name]
      qualified = qualified_name
      names.push(qualified, "::#{qualified}") if qualified
      @check.variable_reads(scope.body).count { |read| names.include?(read) }
    end

    def reads
      count = local_reads
      if qualified_name
        count += outside_reads
        count += external_reads(qualified_name, PuppetLint::Data.path) if count < 2
      end
      count += template_reads if count < 2
      count
    end

    def outside_reads
      # The current buffer takes precedence over its disk version.
      ast.each_node(Ast::M::VariableExpression).count do |node, ancestors|
        !ancestors.include?(@declaration) && node.expr.value.delete_prefix('::') == qualified_name
      end
    end

    def template_reads
      @nodes.sum do |node, ancestors|
        template_call?(node) && visible_template?(ancestors) ? count_template_reads(node, name) : 0
      end
    end

    def template_call?(node)
      node.is_a?(Ast::M::CallNamedFunctionExpression) && %w[template inline_template].include?(node.functor_expr.value)
    end

    def visible_template?(ancestors)
      return false unless ancestors.include?(scope)

      ancestors.drop_while { |ancestor| !ancestor.equal?(scope) }.drop(1).none? { |ancestor| shadows_name?(ancestor) }
    end

    def shadows_name?(ancestor)
      ancestor.is_a?(Ast::M::LambdaExpression) &&
        (ancestor.parameters.map(&:name) + local_names(ancestor.body)).include?(name)
    end

    def external_reads(name, current_path)
      current = File.exist?(current_path) ? File.realpath(current_path) : File.expand_path(current_path)
      @resolver.module_files('manifests/**/*.pp').sum do |path|
        next 0 if current == File.realpath(path)

        external_read_count(name, path)
      end
    end

    def external_read_count(name, path)
      entry = @resolver.source(path)
      return 0 unless entry[:code].include?(name)

      entry[:reads] ||= parsed_reads(entry[:code], path)
      entry[:reads].count(name)
    end

    def parsed_reads(code, path)
      parsed = Ast.new(code, path)
      variable_reads(parsed.program.body).map { |read| read.delete_prefix('::') }
    end

    def count_template_reads(call, name)
      call.arguments.sum do |argument|
        next 0 unless argument.is_a?(Ast::M::LiteralString)

        source = template_code(call, argument)
        source ? instance_variable_reads(source, name) : 0
      end
    end

    def template_code(call, argument)
      call.functor_expr.value == 'inline_template' ? argument.value : @resolver.template_source(argument.value)
    end

    def instance_variable_reads(source, name)
      Ripper.lex(ERB.new(source).src).count { |_position, type, value, _state| type == :on_ivar && value == "@#{name}" }
    end
  end
end
