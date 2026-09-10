require_relative '../../model'
require_relative '../../nullability'

module ProjectLint
  module ResourceCheck
    include ModelCheck
    M = Model::M

    def literal(node)
      case node
      when M::LiteralString, M::LiteralBoolean, M::LiteralInteger, M::QualifiedName then node.value
      when M::LiteralList then node.values.map { |value| literal(value) }
      end
    end

    def apt_options?(node)
      required = ['--no-install-recommends', '--no-install-suggests']
      values = literal(node)
      return (required - values.last(2)).empty? if values.is_a?(Array)
      return false unless node.is_a?(M::CallNamedFunctionExpression) && node.functor_expr.value == 'concat'

      # Unlike union, concat retains duplicate trailing flags, so caller options cannot move the effective policy earlier.
      apt_options?(node.arguments.last)
    end

    # Respect lexically visible resource defaults; unresolved inheritance and overrides need catalog evidence.
    def attributes(resource, body, ancestors)
      attributes = {}
      model.nodes.each do |node, parents|
        next unless node.is_a?(M::ResourceDefaultsExpression)
        next unless node.type_ref.cased_value.downcase == resource.type_name.value
        next unless node.offset < resource.offset && parents.all? { |parent| ancestors.include?(parent) }

        node.operations.grep(M::AttributeOperation).each { |operation| attributes[operation.attribute_name] = operation.value_expr }
      end
      body.operations.grep(M::AttributeOperation).each { |operation| attributes[operation.attribute_name] = operation.value_expr }
      attributes
    end

    # Inherited defaults and resource overrides are catalog contracts, not a proven missing local attribute.
    def indirect_attributes?(resource, parents)
      parents.any? { |parent| parent.is_a?(M::HostClassDefinition) && parent.parent_class } ||
        model.nodes.any? do |node, _|
          node.is_a?(M::ResourceOverrideExpression) && node.resources.is_a?(M::AccessExpression) &&
            node.resources.left_expr.is_a?(M::QualifiedReference) && node.resources.left_expr.cased_value.downcase == resource.type_name.value
        end
    end
  end
end

PuppetLint.new_check(:project_packages) do
  include ProjectLint::ResourceCheck

  def check
    model.nodes.each do |resource, parents|
      next unless resource.is_a?(ProjectLint::Model::M::ResourceExpression) && resource.type_name.value == 'package'

      resource.bodies.each do |body|
        attrs = attributes(resource, body, parents)
        next if %w[absent purged].include?(literal(attrs['ensure']))
        provider = literal(attrs['provider'])
        # Apt options do not apply to explicitly selected non-APT package providers.
        next if provider && !%w[apt aptitude].include?(provider)
        if attrs['provider'] && provider.nil?
          issue(body.title, '[review] Resolve the package provider before checking APT installation options')
        elsif !attrs.key?('install_options')
          message = 'APT package installation must disable recommends and suggests or have a tested central package exception'
          message = '[review] Resolve inherited or overridden APT package attributes in a catalog' if indirect_attributes?(resource, parents)
          issue(body.title, message)
        elsif !apt_options?(attrs['install_options'])
          issue(body.title, '[review] Verify effective APT installation options and any concrete package requirement for recommends or suggests')
        end
      end
    end
  end
end

# Keep mount validation active when a source locally ignores the stricter puppet_url_without_modules check.
PuppetLint.new_check(:project_puppet_urls) do
  def check
    tokens.each do |token|
      # Keep the upstream scope: literal strings and the fixed prefix before interpolation, including source arrays.
      next unless [:SSTRING, :STRING, :DQPRE].include?(token.type) && token.value.start_with?('puppet://')
      next if token.value.match?(%r{\Apuppet://[^/]*/(?:modules|files)/})

      notify(:warning, message: 'puppet:// URL must use a modules/ or files/ mount', line: token.line, column: token.column)
    end
  end

  # No automatic fix: choosing a mount changes the source and requires knowledge of the fileserver layout.
end

PuppetLint.new_check(:project_files) do
  include ProjectLint::ResourceCheck

  def check
    model.nodes.each do |resource, parents|
      next unless resource.is_a?(ProjectLint::Model::M::ResourceExpression) && resource.type_name.value == 'file'

      resource.bodies.each do |body|
        attrs = attributes(resource, body, parents)
        next if literal(attrs['ensure']) == 'absent'

        # Linux symlink modes are fixed by the filesystem; setting mode here cannot harden the target.
        required = literal(attrs['ensure']) == 'link' ? %w[owner group] : %w[owner group mode]
        missing = required - attrs.keys
        unless missing.empty?
          message = "Declare effective file #{missing.join(', ')} explicitly"
          message = '[review] Resolve inherited or overridden file attributes in a catalog' if indirect_attributes?(resource, parents)
          issue(body.title, message)
        end
        mode = literal(attrs['mode'])
        if literal(attrs['recurse']) == true && mode.is_a?(String) && mode.match?(/\A[0-7]{4}\z/) && (mode.to_i(8) & 0o111).positive?
          issue(body.title, '[review] Recursive executable modes require proof that this tree contains only directories or executables; manage mixed trees separately')
        end
        if attrs['source'] && attrs['content'] && !attrs['source'].is_a?(ProjectLint::Model::M::LiteralUndef) && !attrs['content'].is_a?(ProjectLint::Model::M::LiteralUndef)
          unless ProjectLint::Nullability.new(model, resource, parents).exclusive?(attrs['source'], attrs['content'])
            issue(body.title, '[review] Prove source and content cannot both resolve to non-undef values')
          end
        end
      end
    end
  end
end

PuppetLint.new_check(:project_arrays) do
  include ProjectLint::ModelCheck

  # Follow local assignments and declared types; arithmetic and hash addition retain their meaning.
  def array?(node, scope, seen = [])
    m = ProjectLint::Model::M
    return true if node.is_a?(m::LiteralList)
    return false unless node.is_a?(m::VariableExpression)
    name = node.expr.value
    return false if seen.include?(name)

    model.nodes.any? do |candidate, parents|
      candidate_scope = parents.reverse.find { |parent| parent.is_a?(m::NamedDefinition) || parent.is_a?(m::LambdaExpression) }
      next false unless candidate_scope.equal?(scope)

      if candidate.is_a?(m::Parameter) && candidate.name == name
        type = candidate.type_expr
        type.is_a?(m::QualifiedReference) && type.cased_value == 'Array' ||
          type.is_a?(m::AccessExpression) && type.left_expr.is_a?(m::QualifiedReference) && type.left_expr.cased_value == 'Array'
      elsif candidate.is_a?(m::AssignmentExpression) && candidate.left_expr.is_a?(m::VariableExpression) && candidate.left_expr.expr.value == name
        array?(candidate.right_expr, scope, seen + [name])
      end
    end
  end

  def check
    model.nodes.each do |node, parents|
      next unless node.is_a?(ProjectLint::Model::M::ArithmeticExpression) && node.operator == '+'
      scope = parents.reverse.find { |parent| parent.is_a?(ProjectLint::Model::M::NamedDefinition) || parent.is_a?(ProjectLint::Model::M::LambdaExpression) }
      next unless array?(node.left_expr, scope) || array?(node.right_expr, scope)

      issue(node, 'Combine arrays with concat(...) while preserving element order')
    end
  end
end

PuppetLint.new_check(:project_templates) do
  include ProjectLint::ModelCheck

  def check
    model.nodes.each do |node, _|
      next unless node.is_a?(ProjectLint::Model::M::CallNamedFunctionExpression)
      next unless %w[epp inline_epp].include?(node.functor_expr.value)

      issue(node, 'Render generated configuration with template(...) and ERB')
    end
  end
end
