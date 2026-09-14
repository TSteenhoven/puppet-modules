# frozen_string_literal: true

require 'pathname'
require 'project_lint/ast'

module ProjectLint
  # Resolve first-match module sources without following symlinks outside the configured roots.
  class ModuleResolver
    attr_reader :roots

    def initialize
      @explicit = ENV.key?('PROJECT_LINT_MODULEPATH')
      @roots = ENV.fetch('PROJECT_LINT_MODULEPATH', Dir.pwd).split(File::PATH_SEPARATOR, -1).map do |path|
        unless Pathname.new(path).absolute? && File.directory?(path)
          raise ArgumentError, 'PROJECT_LINT_MODULEPATH must contain existing absolute module directories'
        end

        File.realpath(path)
      end.freeze
      raise ArgumentError, 'PROJECT_LINT_MODULEPATH must not be empty' if roots.empty?

      @sources = {}
    end

    def allowed_module?(name)
      @explicit || !%w[concat debconf reboot stdlib timezone].include?(name)
    end

    def first_module_root(name)
      roots.find { |directory| File.directory?(File.join(directory, name)) }
    end

    def file_within_root?(path, root)
      File.file?(path) && File.realpath(path).start_with?("#{root}/")
    end

    def manifest_path(name)
      return unless name.match?(/\A[a-z][a-z0-9_]*(?:::[a-z][a-z0-9_]*)*\z/)

      parts = name.split('::')
      return unless allowed_module?(parts.first)

      root = first_module_root(parts.first)
      return unless root

      suffix = parts.length == 1 ? 'init' : parts.drop(1).join('/')
      path = File.join(root, parts.first, 'manifests', "#{suffix}.pp")
      path if file_within_root?(path, root)
    end

    def source(path)
      stat = File.stat(path)
      stamp = [stat.mtime, stat.ctime, stat.size]
      entry = @sources[path]
      return entry if entry && entry[:stamp] == stamp

      @sources[path] = { stamp: stamp, code: File.read(path) }
    end

    def find(name)
      path = manifest_path(name)
      return unless path

      entry = source(path)
      entry[:declarations] ||= Ast.new(entry[:code], path).declarations.to_h do |declaration|
        [declaration.name, declaration]
      end
      entry[:declarations][name]
    end

    def module_files(pattern)
      seen = []
      roots.flat_map do |root|
        Dir.glob(File.join(root, '*')).sort.flat_map do |directory|
          name = File.basename(directory)
          next [] unless File.directory?(directory) && !seen.include?(name)

          seen << name
          next [] unless allowed_module?(name)

          matching_files(root, directory, pattern)
        end
      end
    end

    def matching_files(root, directory, pattern)
      Dir.glob(File.join(directory, pattern)).select { |path| visible_file?(root, path) }
    end

    def visible_file?(root, path)
      return false unless file_within_root?(path, root)

      relative = path.delete_prefix("#{root}/")
      PuppetLint.configuration.ignore_paths.none? do |ignored|
        File.fnmatch(ignored, relative) || File.fnmatch(ignored, "./#{relative}")
      end
    end

    def template_source(name)
      parts = name.split('/')
      return unless parts.length > 1 && parts.none? { |part| ['.', '..', ''].include?(part) }

      root = first_module_root(parts.first)
      return unless root

      path = File.join(root, parts.first, 'templates', *parts.drop(1))
      source(path)[:code] if file_within_root?(path, root)
    end
  end
end
