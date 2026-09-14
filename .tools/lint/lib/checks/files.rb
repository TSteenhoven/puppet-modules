# frozen_string_literal: true

require_relative '../resource_check'
require_relative '../nullability'

module ProjectLint
  # Check effective file permissions and mutually exclusive content sources.
  module FilesCheck
    include ResourceCheck

    def check
      model.resource_bodies('file').each do |resource, body, parents|
        attrs = attributes(resource, body, parents)
        next if literal(attrs['ensure']) == 'absent'

        check_permissions(resource, body, parents, attrs)
        check_recursive_mode(body, attrs)
        check_content(resource, body, parents, attrs)
      end
    end

    def required_permissions(attrs)
      # Symlink modes are fixed by Linux; mode cannot harden the target.
      literal(attrs['ensure']) == 'link' ? %w[owner group] : %w[owner group mode]
    end

    def check_permissions(resource, body, parents, attrs)
      missing = required_permissions(attrs) - attrs.keys
      return if missing.empty?

      message = "Declare effective file #{missing.join(', ')} explicitly"
      if indirect_attributes?(resource, parents)
        message = '[review] Resolve inherited or overridden file attributes in a catalog'
      end
      issue(body.title, message)
    end

    def check_recursive_mode(body, attrs)
      mode = literal(attrs['mode'])
      return unless literal(attrs['recurse']) == true && executable_mode?(mode)

      issue(body.title, '[review] Recursive executable modes require proof that this tree contains only directories ' \
                        'or executables; manage mixed trees separately')
    end

    def executable_mode?(mode)
      mode.is_a?(String) && mode.match?(/\A[0-7]{4}\z/) && mode.to_i(8).anybits?(0o111)
    end

    def check_content(resource, body, parents, attrs)
      values = attrs.values_at('source', 'content')
      return if values.any? { |value| !value || value.is_a?(Model::M::LiteralUndef) }
      return if Nullability.new(model, resource, parents).exclusive?(*values)

      issue(body.title, '[review] Prove source and content cannot both resolve to non-undef values')
    end
  end
end
