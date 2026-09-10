require_relative '../../model'
require 'pathname'

module ProjectLint
  # Resolve only the interface actually called, using Puppet's conventional manifest path and native AST.
  module Interfaces
    EXPLICIT_MODULEPATH = ENV.key?('PROJECT_LINT_MODULEPATH')
    ROOTS = ENV.fetch('PROJECT_LINT_MODULEPATH', File.expand_path('../../../../..', __dir__)).split(File::PATH_SEPARATOR, -1).map do |path|
      unless Pathname.new(path).absolute? && File.directory?(path)
        raise ArgumentError, 'PROJECT_LINT_MODULEPATH must contain existing absolute module directories'
      end

      File.realpath(path)
    end.freeze
    raise ArgumentError, 'PROJECT_LINT_MODULEPATH must not be empty' if ROOTS.empty?

    def self.find(name)
      return unless name.match?(/\A[a-z][a-z0-9_]*(?:::[a-z][a-z0-9_]*)*\z/)

      parts = name.split('::')
      return if !EXPLICIT_MODULEPATH && %w[concat debconf reboot stdlib timezone].include?(parts.first)

      # Puppet selects the first module directory, even if a later copy contains the missing manifest.
      root = ROOTS.find { |directory| File.directory?(File.join(directory, parts.first)) }
      return unless root

      suffix = parts.length == 1 ? 'init' : parts.drop(1).join('/')
      path = File.join(root, parts.first, 'manifests', "#{suffix}.pp")
      return unless File.file?(path) && File.realpath(path).start_with?("#{root}/")

      @declarations ||= {}
      @declarations[path] ||= Model.new(File.read(path), path).declarations.to_h { |declaration| [declaration.name, declaration] }
      @declarations[path][name]
    end
  end
end

PuppetLint.new_check(:project_interface_calls) do
  include ProjectLint::ModelCheck

  def check
    m = ProjectLint::Model::M
    declarations = model.declarations.to_h { |declaration| [declaration.name, declaration] }
    model.nodes.each do |resource, _|
      next unless resource.is_a?(m::ResourceExpression)

      resource.bodies.each do |body|
        name = resource.type_name.value
        name = body.title.value if name == 'class' && body.title.is_a?(m::LiteralString)
        declaration = declarations[name] || ProjectLint::Interfaces.find(name)
        next unless declaration
        # A splatted attribute hash needs catalog validation; Optional without a default remains required by Puppet.
        next if body.operations.any? { |operation| !operation.is_a?(m::AttributeOperation) }

        supplied = body.operations.map(&:attribute_name)
        missing = declaration.parameters.select { |parameter| parameter.value.nil? }.map(&:name) - supplied
        issue(body.title, "Public interface call omits required parameters: #{missing.join(', ')}") unless missing.empty?
      end
    end
  end
end
