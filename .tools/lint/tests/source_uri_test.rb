# frozen_string_literal: true

require_relative 'test_helper'

# Verify the source uri contract with native lint diagnostics.
class SourceUriTest < Minitest::Test
  include LintTestSupport

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
  end

  def test_source_arrays_accept_both_mounts
    assert_empty findings("$sources = ['puppet:///modules/example/app.tar.gz', 'puppet:///files/example/app.tar.gz']",
                          'project_puppet_urls')
  end

  def test_puppet_sources_reject_unknown_missing_and_partial_mount_names
    ['puppet:///invalid/example/app.tar.gz', 'puppet:///files_backup/example/app.tar.gz',
     'puppet:///modules_extra/example/app.tar.gz',
     'puppet:///files',
     'puppet:///modules',
     'puppet:///',
     'puppet://puppet.example.org',
     'puppet://puppet.example.org/invalid/app.tar.gz'].each do |source|
      assert_invalid_source(source)
    end
  end

  def test_interpolations_and_arrays_report_invalid_mounts
    refute_empty findings('$source = "puppet:///invalid/${path}"', 'project_puppet_urls')
    problems = findings(
      "$sources = ['puppet:///modules/example/app.tar.gz', " \
      "'puppet:///files/example/app.tar.gz', " \
      "'puppet:///invalid/example/app.tar.gz']", 'project_puppet_urls'
    )
    assert_equal 1, problems.length
  end

  def test_puppet_source_check_keeps_other_schemes_and_prose_outside_its_scope
    assert_empty findings("$source = 'https://example.org/app.tar.gz'", 'project_puppet_urls')
    assert_empty findings("$source = 'file:///tmp/example/app.tar.gz'", 'project_puppet_urls')
    assert_empty findings("$message = 'Expected puppet:///modules/ or puppet:///files/'", 'project_puppet_urls')
    assert_empty findings("# puppet:///invalid/example/app.tar.gz\n", 'project_puppet_urls')
    refute_empty findings("$source = 'puppet:///invalid/example/app.tar.gz' # lint:ignore:project_puppet_urls",
                          'project_suppressions')
  end

  def assert_invalid_source(source)
    problems = findings("$source = '#{source}'", 'project_puppet_urls')
    assert_equal 1, problems.length, source
    assert_equal :warning, problems.first.fetch(:kind)
    assert_equal 1, problems.first.fetch(:line)
    assert_equal 11, problems.first.fetch(:column)
  end
end
