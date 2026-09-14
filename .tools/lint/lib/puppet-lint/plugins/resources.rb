# frozen_string_literal: true

require_relative '../../model'
require_relative '../../nullability'

require_relative '../../resource_check'

require_relative '../../checks/packages'

PuppetLint.new_check(:project_packages) do
  include ProjectLint::PackagesCheck
end

# Keep mount validation active when a source locally ignores the stricter puppet_url_without_modules check.
require_relative '../../checks/puppet_urls'

PuppetLint.new_check(:project_puppet_urls) do
  include ProjectLint::PuppetUrlsCheck
end

require_relative '../../checks/files'

PuppetLint.new_check(:project_files) do
  include ProjectLint::FilesCheck
end

require_relative '../../checks/arrays'

PuppetLint.new_check(:project_arrays) do
  include ProjectLint::ArraysCheck
end

require_relative '../../checks/templates'

PuppetLint.new_check(:project_templates) do
  include ProjectLint::TemplatesCheck
end
