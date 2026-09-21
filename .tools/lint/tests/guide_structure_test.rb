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
  RULE_OWNERS = {
    'docs/CODE_RULES.md' => ['Inhoud direct na een openingsaccolade beginnen',
                             'Herhaalde resourceorkestratie in defined types delen',
                             'Prerequisites van ordering onderscheiden'],
    'docs/DOCUMENTATION_RULES.md' => ['Strings-parametercontract', 'Codecommentaar in Engelse zinnen schrijven'],
    'docs/OPERATIONAL_RULES.md' => ['Door Puppet beheerde inhoud markeren',
                                    'Beheerhelpers op de gedeelde locatie installeren',
                                    'Interpreter en shellcompatibiliteit', 'Shellscripts in uitvoervolgorde opbouwen',
                                    'Externe commando’s rechtstreeks vinden', 'Shellcode opmaken en benoemen',
                                    'Shellargumenten en runtime-instellingen verwerken',
                                    'Shellhelpers op een herkenbare taak afbakenen',
                                    'Shellbuffers en tijdelijke bestanden kiezen',
                                    'Tekstbuffers en substitutiemetadata opbouwen',
                                    'Checkexecutables onafhankelijk van targets delen',
                                    'Monitoring onafhankelijk van de waargenomen taak houden',
                                    'Vastgestelde afwijkingen en onvolledige inspecties onderscheiden',
                                    'Firewallconfiguratie bij de deployment houden']
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

  def test_implementation_topics_have_one_owner_across_all_documentation_layers
    headings = [*DOCUMENTS, '../../AGENTS.md'].to_h do |name|
      [name, prose(File.read(File.join(ROOT, name))).scan(/^\#{2,6} (.+)$/).flatten]
    end
    RULE_OWNERS.each do |owner, titles|
      titles.each do |title|
        actual = headings.flat_map { |name, entries| [name] * entries.count(title) }
        assert_equal [owner], actual, title
      end
    end
  end

  def test_workflow_navigation_links_to_the_owning_operational_rules
    agents = File.read(File.join(LintTestSupport::ROOT, 'AGENTS.md'))
    guide = File.read(File.join(ROOT, 'README.md'))
    %w[shellscripts monitoringchecks door-puppet-beheerde-inhoud-markeren
       beheerhelpers-op-de-gedeelde-locatie-installeren].each do |anchor|
      [agents, guide].each do |text|
        assert_includes text, "docs/OPERATIONAL_RULES.md##{anchor})"
      end
    end
  end

  def test_general_workflow_and_documentation_policy_remain_in_agents
    agents = heading_anchors(File.read(File.join(LintTestSupport::ROOT, 'AGENTS.md')))
    assert_includes agents, 'authority-and-rule-placement'
    %w[markdown readme-guidance editorial-review shell-validation monitoring-validation].each do |anchor|
      assert_includes agents, anchor
      RULE_GROUPS.each_key do |name|
        refute_includes heading_anchors(File.read(File.join(ROOT, name))), anchor
      end
    end
  end

  def expected_contents(text)
    headings = prose(text).scan(/^(\#{1,6}) (.+)$/)
    headings.zip(heading_anchors(text)).drop(1).map do |(level, title), anchor|
      "#{'  ' * (level.length - 2)}- [#{title}](##{anchor})"
    end
  end
end
