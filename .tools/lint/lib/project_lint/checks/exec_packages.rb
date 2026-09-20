# frozen_string_literal: true

require 'project_lint/command_packages'
require 'project_lint/package_graph'

module ProjectLint
  # Native checks and their local analyses.
  module Checks
    # Keep runtime package evidence separate from escaping and resource formatting checks.
    module ExecPackages
      include ResourceAttributes

      PROBLEMS = {
        missing_installation: 'no package installation guarantee in the owning code; ' \
                              'a Package reference does not install it',
        missing_order: 'package installation is declared but no dependency path orders it before execution',
        review_installation: 'resolve conditional, external or dynamic package installation evidence',
        review_order: 'package installation is declared; resolve the indirect execution order'
      }.freeze

      def check
        @commands = CommandPackages.new(ast)
        ast.resource_bodies('exec').each do |resource, body, parents|
          attrs = attributes(resource, body, parents)
          uses = command_uses(attrs, body)
          next if uses.empty?

          graph = PackageGraph.new(ast, body, parents + [resource])
          uses.each { |field, value, name| report_package(value, field, name, graph) }
        end
      end

      def command_uses(attrs, body)
        fields = %w[command onlyif unless refresh].to_h { |field| [field, attrs[field]] }
        fields['command'] ||= body.title
        fields.flat_map do |field, value|
          @commands.commands(value, guard: %w[onlyif unless].include?(field)).uniq.filter_map do |name|
            next if %w[command refresh].include?(field) && @commands.optional?(name, attrs['onlyif'])

            [field, value, name]
          end
        end
      end

      def report_package(node, field, name, graph)
        package = CommandPackages::PROVIDERS.fetch(name)
        status = graph.status(package)
        detail = PROBLEMS[status]
        return unless detail

        issue(node, "#{'[review] ' if status.to_s.start_with?('review')}" \
                    "Exec #{field} uses #{name} (#{package}): #{detail}")
      end
    end
    PuppetLint.new_check(:project_exec_packages) { include ExecPackages }
  end
end
