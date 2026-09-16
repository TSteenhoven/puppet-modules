# frozen_string_literal: true

require 'fileutils'
require 'open3'
require 'pathname'
require 'rbconfig'
require 'project_lint/junit_report'

module ProjectLint
  # Runs the native validator once per manifest and reports every result, including failures.
  class PuppetValidate
    def initialize(paths, console)
      @paths = paths.map { |path| Pathname.new(File.expand_path(path)).relative_path_from(Pathname.pwd).to_s }.uniq
      @console = console
    end

    def self.run(arguments, console: $stdout, errors: $stderr)
      report, *paths = arguments
      unless report&.end_with?('.xml')
        errors.puts 'Usage: puppet-validate-junit REPORT.xml MANIFEST.pp [MANIFEST.pp ...]'
        return 1
      end

      FileUtils.mkdir_p(File.dirname(report))
      File.open(report, 'w') { |output| new(paths, console).write(output) }
    rescue SystemCallError => e
      errors.puts "Cannot write Puppet validation JUnit report: #{e.message}"
      1
    end

    def write(output)
      results = validation_results
      counts = result_counts(results)
      JunitReport.write(output, name: 'puppet-validate', **counts) do |xml|
        results.each { |result| write_case(xml, result) }
      end
      @console.puts format('Puppet validate: %<tests>d results, %<failures>d failures, %<errors>d errors.', counts)
      counts.values_at(:failures, :errors).all?(&:zero?) ? 0 : 1
    end

    def validation_results
      return @paths.map { |path| validate(path) } unless @paths.empty?

      [{ path: 'Manifest selection', kind: :error, message: 'No Puppet manifests selected.' }]
    end

    def result_counts(results)
      { tests: results.length, failures: results.count { |r| r[:kind] == :failure },
        errors: results.count { |r| r[:kind] == :error } }
    end

    def validate(path)
      unless path.end_with?('.pp') && File.file?(path)
        return { path: path, kind: :error, message: "Expected an existing .pp file: #{path}" }
      end

      # The active bundle supplies the executable and Ruby; no shell interprets manifest paths.
      output, status = Open3.capture2e(RbConfig.ruby, Gem.bin_path('openvox', 'puppet'),
                                       'parser', 'validate', '--color=false', File.expand_path(path))
      validation_result(path, output, status)
    rescue SystemCallError => e
      { path: path, kind: :error, message: "Cannot start Puppet validator: #{e.message}" }
    end

    def validation_result(path, output, status)
      kind = status.success? ? nil : :failure
      kind = :error if status.signaled?
      output = "Validator failed: #{status}" if kind && output.empty?
      { path: path, kind: kind, message: output }
    end

    def write_case(xml, result)
      path, kind, message = result.values_at(:path, :kind, :message)
      @console.puts "#{path}: #{kind || 'passed'}"
      @console.puts message unless message.empty?
      xml.testcase(classname: 'puppet-validate', name: path, file: path) do
        if kind
          xml.tag!(kind, message, type: kind == :failure ? 'PuppetValidationFailure' : 'ValidationError')
        elsif !message.empty?
          xml.tag!('system-out', message)
        end
      end
    end
  end
end
