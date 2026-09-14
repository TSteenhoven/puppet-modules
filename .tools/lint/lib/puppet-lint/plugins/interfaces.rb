# frozen_string_literal: true

require_relative '../../model'
require 'pathname'

module ProjectLint
  # Resolve only the interface actually called, using Puppet's conventional manifest path and native AST.
  module Interfaces
    EXPLICIT_MODULEPATH = ENV.key?('PROJECT_LINT_MODULEPATH')
    ROOTS = ENV.fetch('PROJECT_LINT_MODULEPATH', File.expand_path('../../../../..', __dir__)).split(
      File::PATH_SEPARATOR, -1
    ).map do |path|
      unless Pathname.new(path).absolute? && File.directory?(path)
        raise ArgumentError, 'PROJECT_LINT_MODULEPATH must contain existing absolute module directories'
      end

      File.realpath(path)
    end.freeze
    raise ArgumentError, 'PROJECT_LINT_MODULEPATH must not be empty' if ROOTS.empty?

    def self.find(name)
      path = manifest_path(name)
      return unless path

      @declarations ||= {}
      @declarations[path] ||= Model.new(File.read(path), path).declarations.to_h do |declaration|
        [declaration.name, declaration]
      end
      @declarations[path][name]
    end

    def self.first_module_root(name)
      ROOTS.find { |directory| File.directory?(File.join(directory, name)) }
    end

    def self.allowed_module?(name)
      EXPLICIT_MODULEPATH || !%w[concat debconf reboot stdlib timezone].include?(name)
    end

    def self.file_within_root?(path, root)
      File.file?(path) && File.realpath(path).start_with?("#{root}/")
    end

    def self.manifest_path(name)
      return unless name.match?(/\A[a-z][a-z0-9_]*(?:::[a-z][a-z0-9_]*)*\z/)

      parts = name.split('::')
      return unless allowed_module?(parts.first)

      root = first_module_root(parts.first)
      manifest_in_root(root, parts) if root
    end

    def self.manifest_in_root(root, parts)
      # Puppet chooses the first module directory even if its manifest is missing.
      suffix = parts.length == 1 ? 'init' : parts.drop(1).join('/')
      path = File.join(root, parts.first, 'manifests', "#{suffix}.pp")
      path if file_within_root?(path, root)
    end
  end
end

require_relative '../../checks/interface_calls'

PuppetLint.new_check(:project_interface_calls) do
  include ProjectLint::InterfaceCallsCheck
end
