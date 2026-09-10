require_relative '../../model'
require_relative 'interfaces' unless defined?(ProjectLint::Interfaces)
require_relative 'layout' unless defined?(ProjectLint::VariableDependencies)
require 'erb'
require 'ripper'

module ProjectLint
  # Count statically visible consumers outside a class without treating comments or plain template text as reads.
  module ClassCheckConsumers
    def self.module_files(pattern)
      seen = []
      Interfaces::ROOTS.flat_map do |root|
        Dir.glob(File.join(root, '*')).sort.flat_map do |directory|
          name = File.basename(directory)
          next [] if seen.include?(name)

          seen << name
          next [] if !Interfaces::EXPLICIT_MODULEPATH && %w[concat debconf reboot stdlib timezone].include?(name)

          Dir.glob(File.join(directory, pattern)).select do |path|
            relative = path.delete_prefix("#{root}/")
            File.file?(path) && File.realpath(path).start_with?("#{root}/") &&
              PuppetLint.configuration.ignore_paths.none? { |ignored| File.fnmatch(ignored, relative) || File.fnmatch(ignored, "./#{relative}") }
          end
        end
      end
    end

    def self.external_reads(name, current_path)
      module_files('manifests/**/*.pp').sum do |path|
        next 0 if File.expand_path(current_path) == File.expand_path(path)

        # Cache by file metadata so editor runs see changed consumers; parse only files mentioning this qualified name.
        stat = File.stat(path)
        @sources ||= {}
        entry = @sources[path]
        entry = @sources[path] = { stamp: [stat.mtime, stat.size], code: File.read(path) } unless entry && entry[:stamp] == [stat.mtime, stat.size]
        next 0 unless entry[:code].include?(name)

        entry[:reads] ||= begin
          parsed = Model.new(entry[:code], path)
          helper = Object.new.extend(VariableDependencies)
          helper.define_singleton_method(:model) { parsed }
          helper.variable_reads(parsed.program.body).map { |read| read.delete_prefix('::') }
        end
        entry[:reads].count(name)
      end
    end

    def self.template_reads(call, name)
      call.arguments.sum do |argument|
        next 0 unless argument.is_a?(Model::M::LiteralString)

        if call.functor_expr.value == 'inline_template'
          source = argument.value
        else
          parts = argument.value.split('/')
          next 0 unless parts.length > 1 && parts.none? { |part| ['.', '..', ''].include?(part) }

          root = Interfaces::ROOTS.find { |directory| File.directory?(File.join(directory, parts.first)) }
          next 0 unless root

          path = File.join(root, parts.first, 'templates', *parts.drop(1))
          next 0 unless File.file?(path) && File.realpath(path).start_with?("#{root}/")

          source = File.read(path)
        end
        Ripper.lex(ERB.new(source).src).count { |_, type, value, _| type == :on_ivar && value == "@#{name}" }
      end
    end
  end
end

PuppetLint.new_check(:project_class_check_reuse) do
  include ProjectLint::VariableDependencies

  def variable_reads(node, bound = [])
    m = ProjectLint::Model::M
    return [] if node.is_a?(m::HostClassDefinition) || node.is_a?(m::ResourceTypeDefinition)

    super
  end

  def class_check(node)
    m = ProjectLint::Model::M
    return unless node.is_a?(m::CallNamedFunctionExpression) && node.functor_expr.value == 'defined' && node.arguments.length == 1

    reference = node.arguments.first
    return unless reference.is_a?(m::AccessExpression) && reference.left_expr.is_a?(m::QualifiedReference)
    return unless reference.left_expr.cased_value == 'Class' && reference.keys.length == 1 && reference.keys.first.is_a?(m::LiteralString)

    reference.keys.first.value.downcase.delete_prefix('::')
  end

  def check
    m = ProjectLint::Model::M
    declarations = model.declarations
    declarations.each do |declaration|
      next unless declaration.body

      nodes = model.nodes.select do |node, parents|
        (node.equal?(declaration.body) || parents.include?(declaration.body)) &&
          parents.reverse.find { |parent| declarations.include?(parent) }.equal?(declaration)
      end
      calls = nodes.select { |node, _| class_check(node) }.group_by { |node, _| class_check(node) }
      calls.each_value do |occurrences|
        if occurrences.length > 1
          occurrences.drop(1).each do |call, _|
            issue(call, 'Evaluate repeated defined(Class[...]) checks once in a shared variable within this class or define; preserve evaluation order')
          end
          next
        end

        call, parents = occurrences.first
        ancestors = parents.dup
        ancestors.pop while ancestors.last.is_a?(m::ParenthesizedExpression) || ancestors.last.is_a?(m::NotExpression)
        assignment = ancestors.last
        next unless assignment.is_a?(m::AssignmentExpression) && assignment.left_expr.is_a?(m::VariableExpression)

        name = assignment.left_expr.expr.value
        scope = ancestors.reverse.find { |parent| parent.is_a?(m::LambdaExpression) } || declaration
        names = [name]
        qualified = "#{declaration.name}::#{name}" if scope.equal?(declaration) && declaration.is_a?(m::HostClassDefinition)
        names.concat([qualified, "::#{qualified}"]) if qualified
        reads = variable_reads(scope.body).count { |read| names.include?(read) }
        if qualified
          # The current buffer takes precedence over its on-disk version, including other declarations in that buffer.
          outside = model.nodes.select { |node, ancestors| node.is_a?(m::VariableExpression) && !ancestors.include?(declaration) }
          reads += outside.count { |node, _| node.expr.value.delete_prefix('::') == qualified }
          reads += ProjectLint::ClassCheckConsumers.external_reads(qualified, PuppetLint::Data.path) if reads < 2
        end
        if reads < 2
          nodes.each do |node, ancestors|
            next unless node.is_a?(m::CallNamedFunctionExpression) && %w[template inline_template].include?(node.functor_expr.value)
            next unless ancestors.include?(scope)
            next if ancestors.drop_while { |ancestor| !ancestor.equal?(scope) }.drop(1).any? do |ancestor|
              ancestor.is_a?(m::LambdaExpression) && (ancestor.parameters.map(&:name) + local_names(ancestor.body)).include?(name)
            end

            reads += ProjectLint::ClassCheckConsumers.template_reads(node, name)
          end
        end
        next if reads > 1

        message = if reads == 1
                    'Inline a defined(Class[...]) result used only once; keep a shared variable only for repeated use and preserve evaluation order'
                  else
                    'Remove an unused defined(Class[...]) variable; verify indirect consumers before changing it'
                  end
        issue(assignment.left_expr, message)
      end
    end
  end
end
