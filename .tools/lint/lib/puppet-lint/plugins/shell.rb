# frozen_string_literal: true

require_relative '../../checks/shell'

PuppetLint.new_check(:project_shell) do
  include ProjectLint::ShellCheck
end
