# frozen_string_literal: true

module ProjectLint
  # Enumerate first-match modules while honoring lint exclusions and symlink boundaries.
  class ModuleFiles
    def initialize(pattern)
      @pattern = pattern
      @seen = []
    end

    def paths
      Interfaces::ROOTS.flat_map do |root|
        Dir.glob(File.join(root, '*')).sort.flat_map { |directory| module_paths(root, directory) }
      end
    end

    def module_paths(root, directory)
      name = File.basename(directory)
      return [] if @seen.include?(name)

      @seen << name
      return [] unless Interfaces.allowed_module?(name)

      Dir.glob(File.join(directory, @pattern)).select { |path| visible_file?(root, path) }
    end

    def visible_file?(root, path)
      return false unless Interfaces.file_within_root?(path, root)

      relative = path.delete_prefix("#{root}/")
      PuppetLint.configuration.ignore_paths.none? do |ignored|
        File.fnmatch(ignored, relative) || File.fnmatch(ignored, "./#{relative}")
      end
    end
  end
end
