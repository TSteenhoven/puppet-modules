# frozen_string_literal: true

require_relative 'test_helper'
require_relative 'guide_links_support'

# Keep tooling, general rules, documentation rules and operational rules in their assigned files.
class GuideStructureTest < Minitest::Test
  include ProjectLint::GuideLinks

  ROOT = File.join(LintTestSupport::ROOT, '.tools/lint')
  DOCUMENTS = %w[README.md docs/CODE_RULES.md docs/DOCUMENTATION_RULES.md docs/OPERATIONAL_RULES.md].freeze
  SIZE_LIMIT = 300 * 1024
  RULE_GROUPS = {
    'docs/CODE_RULES.md' => ['Basisopmaak', 'Inspringing', "Komma's", 'Lange regels',
                             'Parameters en resources'],
    'docs/DOCUMENTATION_RULES.md' => ['Commentaar en documentatie'],
    'docs/OPERATIONAL_RULES.md' => ['Bestanden en beveiliging', 'Gedeelde services en systemd', 'Shellscripts',
                                    'Monitoringchecks']
  }.freeze

  def test_exactly_four_documents_with_all_rule_documents_linked_from_the_readme
    documents = Dir[File.join(ROOT, '**/*.md')].map { |path| path.delete_prefix("#{ROOT}/") }
    assert_equal DOCUMENTS.sort, documents.sort
    readme = prose(File.read(File.join(ROOT, 'README.md')))
    RULE_GROUPS.each_key do |name|
      assert_match(/\]\(#{Regexp.escape(name)}(?:#[^)]*)?\)/, readme, "README must link to #{name}")
    end
  end

  def test_each_document_stays_strictly_below_the_project_size_limit
    DOCUMENTS.each do |name|
      path = File.join(ROOT, name)
      assert_path_exists path
      size = File.size(path)
      assert_operator size, :<, SIZE_LIMIT,
                      "#{name} is #{size} bytes; project limit is strictly below #{SIZE_LIMIT} bytes (300 KiB)"
    end
  end

  def test_rule_groups_have_their_assigned_owner_without_a_second_registry
    RULE_GROUPS.each do |name, groups|
      text = prose(File.read(File.join(ROOT, name)))
      assert_equal ['Inhoudsopgave', *groups], text.scan(/^## (.+)$/).flatten, name
      refute_includes text, '<!-- BEGIN PROJECT CHECK REGISTRY -->', name
      refute_match(/^\| Check \| Actief in repositoryprofiel \|/, text, name)
    end
  end

  def test_all_documents_link_every_heading_in_order_without_duplicate_anchors
    DOCUMENTS.each do |name|
      text = File.read(File.join(ROOT, name))
      contents = text[/^## Inhoudsopgave\n(.*?)(?=^## )/m, 1]
      assert_equal expected_contents(text), contents.lines.grep(/^ *- /).map(&:chomp), name
      assert_equal anchors(text).uniq, anchors(text), "Duplicate anchors in #{name}"
    end
  end

  def expected_contents(text)
    headings = prose(text).scan(/^(\#{1,6}) (.+)$/)
    headings.zip(heading_anchors(text)).drop(1).map do |(level, title), anchor|
      "#{'  ' * (level.length - 2)}- [#{title}](##{anchor})"
    end
  end
end
