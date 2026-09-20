# frozen_string_literal: true

module ProjectLint
  class PackageGraph
    # Keep alternatives separate, including the empty route of an incomplete choice.
    class Branches
      attr_reader :decisions

      def initialize(decisions)
        @decisions = decisions
        @pending = {}.compare_by_identity
      end

      def alternatives(node)
        case node
        when Ast::M::IfExpression, Ast::M::UnlessExpression then [node.then_expr, node.else_expr]
        when Ast::M::CaseExpression then case_alternatives(node)
        end
      end

      def case_alternatives(node)
        options = node.options.to_a
        default = options.any? { |option| option.values.any?(Ast::M::LiteralDefault) }
        default ? options : options + [nil]
      end

      def selection(node, path)
        index = path.index { |parent| parent.equal?(node) }
        return [true, path[index + 1]] if index

        [decisions.key?(node), decisions[node]]
      end

      def possible?(parents, path)
        parents.each_cons(2).all? do |parent, child|
          known, selected = selection(parent, path)
          !alternatives(parent) || !known || selected.equal?(child)
        end
      end

      def record(parents, path, keys)
        parents.each do |parent|
          next unless alternatives(parent) && !selection(parent, path).first

          @pending[parent] ||= []
          @pending[parent] |= keys || [nil]
        end
      end

      def next_choice(needed)
        @pending.find { |_node, keys| !(keys & needed).empty? }&.first ||
          @pending.find { |_node, keys| keys.include?(nil) }&.first
      end

      def expand(node)
        alternatives(node).map { |option| decisions.merge(node => option) }
      end
    end

    # Prove each relevant alternative using the same installation and relationship analysis.
    module BranchAnalysis
      MAX_STATES = 128
      INSTALLATION_FAILURES = %i[missing_installation review_installation].freeze

      def status(package)
        pending = [nil]
        results = []
        MAX_STATES.times do
          break if pending.empty?

          graph = pending.last ? dup.build(pending.pop) : tap { pending.pop }
          explore(graph, package, pending, results)
        end
        results << unresolved_status(package) unless pending.empty?
        combined_status(results)
      end

      def unresolved_status(package)
        INSTALLATION_FAILURES.include?(path_status(package)) ? :review_installation : :review_order
      end

      def read_termination(source)
        source.nodes(Ast::M::CallNamedFunctionExpression).each do |node, parents|
          next unless node.functor_expr.value.delete_prefix('::') == 'fail'

          source.record_branches(node, parents)
          @failed = true if source.guaranteed?(parents, node)
        end
      end

      def explore(graph, package, pending, results)
        return if graph.failed

        status = graph.path_status(package)
        choice = graph.branch_choice(package) unless status == :installed_and_ordered
        if choice
          pending.concat(graph.branches.expand(choice))
        else
          results << status
        end
      end

      def branch_choice(package)
        branches.next_choice([target, ['package', package]] + prerequisites(target))
      end

      def combined_status(results)
        return :unreachable if results.empty?

        return results.first if results.uniq.one?
        return :review_installation unless (results & INSTALLATION_FAILURES).empty?

        :review_order
      end
    end
  end
end
