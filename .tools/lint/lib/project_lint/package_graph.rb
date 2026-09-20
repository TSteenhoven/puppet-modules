# frozen_string_literal: true

require 'project_lint/resource_attributes'
require 'project_lint/resource_values'
require 'project_lint/module_resolver'
require 'project_lint/package_graph/branches'

module ProjectLint
  # A bounded source graph: installation evidence and ordering evidence are independent.
  class PackageGraph
    # Read fixed values and resource identities with the existing lexical value analysis.
    class Source
      include ResourceAttributes

      attr_reader :ast, :scope, :path

      def initialize(ast, scope, path, branches)
        @ast = ast
        @scope = scope
        @path = path
        @branches = branches
        @values = ResourceValues.new(ast, local_value: method(:local_value))
        @literals = ParameterSource.new(ast)
        @parents = {}.compare_by_identity
        ast.nodes.each { |node, parents| @parents[node] = parents }
      end

      def value(node, seen = [])
        return if seen.any? { |item| item.equal?(node) }
        return value(@values.local_value(node), seen + [node]) if node.is_a?(Ast::M::VariableExpression)

        @literals.literal(node)&.first
      end

      def local_value(variable)
        parents = @parents.fetch(variable, [])
        candidates = @literals.assignments(variable, parents).select do |assignment, ancestors|
          @branches.possible?(ancestors + [assignment], parents)
        end
        candidates.each { |assignment, ancestors| record_branches(assignment, ancestors) }
        return unless candidates.one?

        assignment, ancestors = candidates.first
        assignment.right_expr if assignment.offset < variable.offset && guaranteed?(ancestors, assignment, parents)
      end

      def names(node)
        known = value(node)
        return [known] if known.is_a?(String)

        @values.names(node)
      end

      def references(node, seen = [])
        return [] if node.nil?
        return if seen.any? { |item| item.equal?(node) }

        return variable_references(node, seen) if node.is_a?(Ast::M::VariableExpression)
        return reference_keys(node) if @values.reference?(node)

        combined_references(node, seen)
      end

      def combined_references(node, seen)
        parts = reference_children(node)&.map { |child| references(child, seen + [node]) }
        parts.flatten(1) if parts&.none?(&:nil?)
      end

      def variable_references(node, seen)
        origin = @values.local_value(node)
        references(origin, seen + [node]) if origin
      end

      def reference_children(node)
        return node.values if node.is_a?(Ast::M::LiteralList)

        node.arguments if @values.concat?(node)
      end

      def reference_keys(node)
        titles = node.keys.map { |key| names(key) }
        titles.flatten.map { |title| [node.left_expr.value, title] } if titles.none?(&:nil?)
      end

      def own?(parents)
        ast.scope_of(parents).equal?(scope)
      end

      def guaranteed?(parents, node, context = path)
        ancestors = scope ? parents.drop_while { |parent| !parent.equal?(scope) } : parents
        own?(parents) && (ancestors + [node]).each_cons(2).all? { |parent, child| reachable?(parent, child, context) }
      end

      def reachable?(parent, child, context)
        if @branches.alternatives(parent)
          known, selected = @branches.selection(parent, context)
          return known && selected.equal?(child)
        end
        unconditional?(parent) || context.any? { |item| item.equal?(parent) }
      end

      def unconditional?(parent)
        return true if [ast.program, scope, scope&.body].any? { |item| item.equal?(parent) }

        [Ast::M::RelationshipExpression, Ast::M::BlockExpression, Ast::M::CaseOption].any? { |type| parent.is_a?(type) }
      end

      def nodes(type)
        ast.each_node(type).select { |node, parents| own?(parents) && @branches.possible?(parents + [node], path) }
      end

      def record_branches(node, parents, keys = nil)
        @branches.record(parents + [node], path, keys)
      end

      def resources
        nodes(Ast::M::ResourceExpression).flat_map do |resource, parents|
          resource.bodies.map { |body| resource_entry(resource, body, parents) }
        end
      end

      def resource_entry(resource, body, parents)
        record_branches(resource, parents,
                        resource.type_name.value == 'class' ? nil : resource_evidence(resource, body))
        { keys: Array(names(body.title)).map { |title| [resource.type_name.value, title] }, body: body,
          attrs: attributes(resource, body, parents), type: resource.type_name.value,
          guaranteed: guaranteed?(parents, resource) && resource.form == 'regular',
          indirect: indirect_attributes?(resource, parents) }
      end

      def resource_evidence(resource, body)
        keys = Array(names(body.title)).map { |title| [resource.type_name.value, title] }
        body.operations.grep(Ast::M::AttributeOperation).each do |attribute|
          next unless %w[require subscribe before notify].include?(attribute.attribute_name)

          keys.concat(references(attribute.value_expr) || [nil])
        end
        keys.empty? ? nil : keys
      end
    end

    # Collect package state without mistaking references or conditional declarations for installation.
    module Installations
      def record_package(source, entry)
        attrs = entry[:attrs]
        state = attrs.key?('ensure') ? source.value(attrs['ensure']) : 'installed'
        names = entry[:keys].map(&:last)
        @incomplete = true if names.empty?
        if uncertain_package?(source, entry, state)
          @uncertain_packages.concat(names)
        elsif installed_state?(state)
          @installed.concat(names)
        end
      end

      def uncertain_package?(source, entry, state)
        attrs = entry[:attrs]
        !entry[:guaranteed] || entry[:indirect] || state.nil? || attrs.key?('name') ||
          (attrs.key?('provider') && !%w[apt aptitude].include?(source.value(attrs['provider'])))
      end

      def installed_state?(state)
        state.is_a?(String) && !%w[absent purged].include?(state)
      end

      def read_installers(source, class_key)
        source.nodes(Ast::M::CallNamedFunctionExpression).each do |node, parents|
          next unless %w[ensure_packages stdlib::ensure_packages].include?(node.functor_expr.value.delete_prefix('::'))

          source.record_branches(node, parents, source.names(node.arguments.first)&.map { |name| ['package', name] })
          read_installer(source, node, parents, class_key)
        end
      end

      def read_installer(source, node, parents, class_key)
        names = source.names(node.arguments.first)
        options = node.arguments.length < 2 ? {} : source.value(node.arguments[1])
        @incomplete = true unless names
        return unless names

        if source.guaranteed?(parents, node) && installing_options?(options)
          @installed.concat(names)
          record_installed_keys(names, class_key)
        else
          @uncertain_packages.concat(names)
        end
      end

      def installing_options?(options)
        options.is_a?(Hash) && installed_state?(options.fetch('ensure', 'installed')) &&
          !options.key?('name') && (!options.key?('provider') || %w[apt aptitude].include?(options['provider']))
      end

      def record_installed_keys(names, class_key)
        names.each do |name|
          key = ['package', name]
          @known << key
          @edges[class_key] << key if class_key
        end
      end
    end

    # Follow ordinary metaparameters and arrows; leave collectors and dynamic references unresolved.
    module Relationships
      def read_attributes(source, key, attrs)
        %w[require subscribe before notify].each do |attribute|
          next unless attrs.key?(attribute)

          refs = source.references(attrs[attribute])
          if refs
            refs.each { |reference| add_attribute_edge(key, reference, attribute) }
          else
            @unresolved << key
          end
        end
      end

      def add_attribute_edge(key, reference, attribute)
        receiver, prerequisite = %w[require subscribe].include?(attribute) ? [key, reference] : [reference, key]
        @edges[receiver] << prerequisite
      end

      def read_relationships(source)
        source.nodes(Ast::M::RelationshipExpression).each do |node, parents|
          source.record_branches(node, parents, relationship_evidence(source, node))
          next unless source.guaranteed?(parents, node)

          read_relationship(source, node)
        end
      end

      def relationship_evidence(source, node)
        left = relationship_keys(source, node.left_expr)
        right = relationship_keys(source, node.right_expr)
        left + right if left && right
      end

      def read_relationship(source, node)
        left = relationship_keys(source, node.left_expr)
        right = relationship_keys(source, node.right_expr)
        unless left && right
          @incomplete = true
          return
        end
        left, right = right, left if %w[<- <~].include?(node.operator)
        right.each { |key| @edges[key].concat(left) }
      end

      def relationship_keys(source, node)
        return relationship_keys(source, node.right_expr) if node.is_a?(Ast::M::RelationshipExpression)
        return source.references(node) unless node.is_a?(Ast::M::ResourceExpression)

        parts = node.bodies.map { |body| declaration_keys(source, node, body) }
        parts.flatten(1) if parts.none?(&:nil?)
      end

      def declaration_keys(source, resource, body)
        keys = source.names(body.title)&.map { |title| [resource.type_name.value, title] }
        body.equal?(@target_body) ? Array(keys) + [target] : keys
      end

      def prerequisites(key, seen = [])
        return [] if seen.include?(key)

        @edges[key].flat_map { |parent| [parent] + prerequisites(parent, seen + [key]) }.uniq
      end
    end

    # Reuse class-owned packages only when the analyzed execution path requires that class.
    module Classes
      def read_classes(source)
        source.nodes(Ast::M::CallNamedFunctionExpression).each do |node, parents|
          function = node.functor_expr.value.delete_prefix('::')
          next unless %w[include contain require].include?(function)

          source.record_branches(node, parents)
          next unless source.guaranteed?(parents, node)

          node.arguments.each { |argument| read_class_call(source, argument, function) }
        end
      end

      def read_class_call(source, argument, function)
        names = source.names(argument)
        @incomplete = true unless names
        Array(names).each do |name|
          import_class(name)
          require_class(source, name) if function == 'require'
        end
      end

      def require_class(source, name)
        source.resources.select { |entry| entry[:guaranteed] }.each do |entry|
          entry[:keys].each { |key| @edges[key] << ['class', name] }
          @edges[target] << ['class', name] if entry[:body].equal?(@target_body)
        end
      end

      def import_class(name)
        return if @classes.include?(name)

        @classes << name
        analysis = class_ast(name)
        declaration = analysis&.declarations&.find { |node| node.name == name }
        if declaration.is_a?(Ast::M::HostClassDefinition)
          read_class(analysis, declaration, name)
        else
          @incomplete = true
        end
      end

      def read_class(analysis, declaration, name)
        @incomplete = true if declaration.parent_class
        key = ['class', name]
        @known << key
        read_source(Source.new(analysis, declaration, [], branches), key)
      end

      def class_ast(name)
        return @root if @root.declarations.any? { |node| node.name == name }

        path = @resolver.manifest_path(name)
        @class_asts[name] ||= Ast.new(@resolver.source(path)[:code], path) if path
      end

      def guarded_classes(parents)
        (parents + [@target_body]).each_cons(2).flat_map do |parent, child|
          next [] unless parent.is_a?(Ast::M::IfExpression) && child.equal?(parent.then_expr)

          positive_classes(parent.test)
        end
      end

      def positive_classes(node)
        case node
        when Ast::M::ParenthesizedExpression then positive_classes(node.expr)
        when Ast::M::AndExpression then positive_classes(node.left_expr) + positive_classes(node.right_expr)
        when Ast::M::CallNamedFunctionExpression then defined_classes(node)
        else []
        end
      end

      def defined_classes(node)
        return [] unless node.functor_expr.value == 'defined'

        refs = @source.references(node.arguments.first)
        # defined() accepts alternatives; only one reference proves the specific parent is declared.
        unless node.arguments.length == 1 && refs&.length == 1
          @incomplete = true
          return []
        end
        refs.filter_map { |type, name| name if type == 'class' }
      end
    end

    include Installations
    include Relationships
    include Classes
    include BranchAnalysis

    attr_reader :target, :branches, :failed

    def initialize(ast, body, parents)
      @resolver = ModuleResolver.new
      @root = ast
      @parents = parents
      @class_asts = {}
      @target_body = body
      @target = ['exec', body.object_id]
      build({}.compare_by_identity)
    end

    def build(decisions)
      @branches = Branches.new(decisions)
      @source = Source.new(@root, @root.scope_of(@parents), @parents, branches)
      initialize_evidence
      read_source(@source)
      guarded_classes(@parents).each { |name| import_class(name) }
      self
    end

    def initialize_evidence
      @edges = Hash.new { |hash, key| hash[key] = [] }
      @installed = []
      @uncertain_packages = []
      @known = []
      @unresolved = []
      @overridden = []
      @classes = []
      @incomplete = false
      @failed = false
    end

    def read_source(source, class_key = nil)
      @incomplete = true if source.scope.is_a?(Ast::M::HostClassDefinition) && source.scope.parent_class
      source.resources.each { |entry| read_resource(source, entry, class_key) }
      read_installers(source, class_key)
      read_relationships(source)
      read_classes(source)
      read_indirect_resources(source)
      read_termination(source)
    end

    def read_indirect_resources(source)
      if source.nodes(Ast::M::CollectExpression).any? || source.nodes(Ast::M::ResourceOverrideExpression).any?
        @incomplete = true
        @overridden << target
      end
      @incomplete = true if source.nodes(Ast::M::CallNamedFunctionExpression).any? do |node, _parents|
        %w[create_resources ensure_resources].include?(node.functor_expr.value.delete_prefix('::'))
      end
    end

    def read_resource(source, entry, class_key)
      keys = resource_keys(entry)
      @incomplete = true if entry[:type].include?('::')
      @known.concat(keys) if entry[:guaranteed]
      record_package(source, entry) if entry[:type] == 'package'
      return unless entry[:guaranteed]

      read_resource_edges(source, entry, keys, class_key)
      keys.each { |key| import_class(key.last) } if entry[:type] == 'class'
    end

    def resource_keys(entry)
      keys = entry[:keys]
      return keys unless entry[:body].equal?(@target_body)

      @edges[target].concat(keys)
      keys + [target]
    end

    def read_resource_edges(source, entry, keys, class_key)
      keys.each do |key|
        @edges[class_key] << key if class_key
        read_attributes(source, key, entry[:attrs])
      end
      @overridden.concat(keys) if entry[:indirect]
    end

    def path_status(package)
      preceding = prerequisites(target)
      installed = @installed.include?(package) && !@uncertain_packages.include?(package)
      uncertain = uncertain?(package, preceding)
      return uncertain ? :review_installation : :missing_installation unless installed
      return :installed_and_ordered if preceding.include?(['package', package]) && !overridden?(preceding)

      uncertain ? :review_order : :missing_order
    end

    def uncertain?(package, preceding)
      @incomplete || @uncertain_packages.include?(package) || unresolved?(preceding) || overridden?(preceding) ||
        preceding.any? { |key| !@known.include?(key) && key != ['package', package] }
    end

    def unresolved?(preceding)
      ([target] + preceding).any? { |key| @unresolved.include?(key) }
    end

    def overridden?(preceding)
      ([target] + preceding).any? { |key| @overridden.include?(key) }
    end
  end
end
