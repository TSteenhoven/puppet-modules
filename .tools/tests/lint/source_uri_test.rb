# frozen_string_literal: true

require_relative 'check_test_case'

# Verify the source uri contract with native lint diagnostics.
class SourceUriTest < CheckTestCase
  def test_puppet_sources_accept_module_and_fileserver_mounts
    %w[modules files].each do |mount|
      ["puppet:///#{mount}/example/app.tar.gz",
       "puppet://puppet.example.org/#{mount}/example/app.tar.gz"].each do |source|
        assert_empty findings("$source = '#{source}'", 'project_puppet_urls')
        assert_empty findings("$source = \"#{source}\"", 'project_puppet_urls')
      end
      assert_empty findings(%($source = "puppet:///#{mount}/example/${filename}"), 'project_puppet_urls')
      assert_empty findings(%($source = "puppet:///#{mount}/${path}"), 'project_puppet_urls')
    end
    assert_empty findings(fixture(:sample), 'project_puppet_urls')
  end

  def test_puppet_sources_reject_unknown_missing_and_partial_mount_names
    fixture(:samples).each { |source| assert_invalid_source(source) }
    refute_empty findings('$source = "puppet:///invalid/${path}"', 'project_puppet_urls')
    problems = findings(
      fixture(:problems), 'project_puppet_urls'
    )
    assert_equal 1, problems.length
  end

  def test_puppet_source_check_keeps_other_schemes_and_prose_outside_its_scope
    assert_empty findings("$source = 'https://example.org/app.tar.gz'", 'project_puppet_urls')
    assert_empty findings("$source = 'file:///tmp/example/app.tar.gz'", 'project_puppet_urls')
    assert_empty findings("$message = 'Expected puppet:///modules/ or puppet:///files/'", 'project_puppet_urls')
    assert_empty findings(fixture(:sample), 'project_puppet_urls')
    refute_empty findings(fixture(:sample2), 'project_suppressions')
  end

  def assert_invalid_source(source)
    problems = findings("$source = '#{source}'", 'project_puppet_urls')
    assert_equal 1, problems.length, source
    assert_equal :warning, problems.first.fetch(:kind)
    assert_equal 1, problems.first.fetch(:line)
    assert_equal 11, problems.first.fetch(:column)
  end
end
