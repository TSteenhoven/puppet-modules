# frozen_string_literal: true

require_relative 'test_helper'
require_relative 'installed_gem_support'

# Keep the guide and its rule targets available to independently installed consumers.
class ExternalGuideTest < Minitest::Test
  include InstalledGemSupport

  def test_installed_package_contains_all_four_complete_documents
    %w[README.md docs/CODE_RULES.md docs/DOCUMENTATION_RULES.md docs/OPERATIONAL_RULES.md].each do |name|
      assert_equal File.read(File.join(LintTestSupport::ROOT, '.tools/lint', name)),
                   File.read(File.join(@installed, name)), "Packaged #{name} must retain its complete contents"
    end
  end
end
