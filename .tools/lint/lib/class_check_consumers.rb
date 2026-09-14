# frozen_string_literal: true

require_relative 'module_files'
require_relative 'variable_dependencies'
require 'erb'
require 'ripper'

module ProjectLint
  # Count actual Puppet and ERB reads, refreshing cached sources when file metadata changes.
  module ClassCheckConsumers
    def self.module_files(pattern)
      ModuleFiles.new(pattern).paths
    end

    def self.external_reads(name, current_path)
      module_files('manifests/**/*.pp').sum do |path|
        next 0 if File.expand_path(current_path) == File.expand_path(path)

        external_read_count(name, path)
      end
    end

    def self.source_entry(path)
      stat = File.stat(path)
      stamp = [stat.mtime, stat.size]
      @sources ||= {}
      entry = @sources[path]
      return entry if entry && entry[:stamp] == stamp

      @sources[path] = { stamp: stamp, code: File.read(path) }
    end

    def self.external_read_count(name, path)
      entry = source_entry(path)
      return 0 unless entry[:code].include?(name)

      entry[:reads] ||= parsed_reads(entry[:code], path)
      entry[:reads].count(name)
    end

    def self.parsed_reads(code, path)
      parsed = Model.new(code, path)
      helper = Object.new.extend(VariableDependencies)
      helper.define_singleton_method(:model) { parsed }
      helper.variable_reads(parsed.program.body).map { |read| read.delete_prefix('::') }
    end

    def self.template_reads(call, name)
      call.arguments.sum do |argument|
        next 0 unless argument.is_a?(Model::M::LiteralString)

        source = call.functor_expr.value == 'inline_template' ? argument.value : template_source(argument.value)
        source ? instance_variable_reads(source, name) : 0
      end
    end

    def self.template_source(name)
      parts = name.split('/')
      return unless parts.length > 1 && parts.none? { |part| ['.', '..', ''].include?(part) }

      root = Interfaces.first_module_root(parts.first)
      return unless root

      path = File.join(root, parts.first, 'templates', *parts.drop(1))
      File.read(path) if Interfaces.file_within_root?(path, root)
    end

    def self.instance_variable_reads(source, name)
      Ripper.lex(ERB.new(source).src).count { |_position, type, value, _state| type == :on_ivar && value == "@#{name}" }
    end
  end
end
