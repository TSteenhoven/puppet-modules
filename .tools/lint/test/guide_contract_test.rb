# frozen_string_literal: true

require_relative 'test_helper'

# Check the guide's bounded technical structure against the loaded public interfaces.
class GuideContractTest < Minitest::Test
  include LintTestSupport

  GUIDE = File.join(LintTestSupport::ROOT, '.tools/lint/README.md')
  FIELDS = ['Norm', 'Herkomst', 'Toepassingsgebied', 'Automatische controle', 'Detectiegrenzen',
            'Meldingen en severity', 'Autofix', 'Autofixvoorwaarden', 'Toegestane uitzonderingen',
            'Suppressions', 'Onjuist voorbeeld', 'Correct voorbeeld', 'Grensgevallen',
            'Handmatige review', 'Verificatie'].freeze
  PROFILE_QUERY = <<~RUBY
    require 'project_lint'
    require 'json'
    PuppetLint::OptParser.build(['--no-config', '--config', ARGV.fetch(0)])
    puts JSON.generate(PuppetLint.configuration.checks.to_h do |check|
      [check, PuppetLint.configuration.public_send("\#{check}_enabled?")]
    end)
  RUBY

  def guide
    File.read(GUIDE)
  end

  def registry
    table = guide.match(/^<!-- BEGIN PROJECT CHECK REGISTRY -->\n(.*?)^<!-- END PROJECT CHECK REGISTRY -->/m)
    refute_nil table, 'Missing bounded project check registry'
    table[1].lines.grep(/^\| `project_/).map { |line| line.split('|')[1..].map(&:strip) }
  end

  def test_registry_has_no_missing_unknown_or_duplicate_runtime_checks
    registered = PuppetLint.configuration.checks.grep(/^project_/).map(&:to_s).sort
    names = registry.map { |row| row.first.delete('`') }
    assert_empty registered - names, 'Missing registered project checks'
    assert_empty names - registered, 'Unknown project checks'
    assert_empty names.tally.select { |_name, count| count > 1 }, 'Duplicate project checks'
  end

  def profile_checks(profile)
    output, errors, status = Open3.capture3(RbConfig.ruby, '-e', PROFILE_QUERY, profile, chdir: LintTestSupport::ROOT)
    assert status.success?, errors
    JSON.parse(output)
  end

  def test_registry_activation_and_rule_links_match_both_profiles
    repository = profile_checks('.puppet-lint.rc')
    shared = profile_checks('.tools/lint/config/puppet-lint.rc')
    registry.each do |row|
      check = row.first.delete('`')
      assert_equal repository.fetch(check) ? 'Ja' : 'Nee', row[1], check
      assert_equal shared.fetch(check) ? 'Ja' : 'Nee', row[2], check
      row.values_at(3, 5).each { |cell| assert_registry_links(cell, check) }
    end
  end

  def assert_registry_links(cell, check)
    links = cell.scan(/\]\(#([^)]*)\)/).flatten
    refute_empty links, "Missing rule links for #{check}"
    links.each { |link| assert_includes anchors(guide), link, check }
  end

  def prose(text)
    text.gsub(/^```[^\n]*\n.*?^```\s*$/m, '')
  end

  def anchors(text)
    visible = prose(text)
    headings = visible.scan(/^\#{1,6} (.+)$/).flatten.map do |heading|
      heading.downcase.gsub(/[^\p{Word}\s-]/, '').tr(' ', '-')
    end
    headings + visible.scan(%r{<a id="([^"]+)"></a>}).flatten
  end

  def rule_blocks
    chapter = guide.split('## Puppet-coderegels en reviewcriteria', 2).last.split('## Autofix en suppressions', 2).first
    prose(chapter).split(/(?=^\#{3,4} )/).drop(1).reject { |block| block.include?('<!-- lint-rule-group -->') }
  end

  def test_each_rule_has_all_nonempty_fields_in_order
    refute_empty rule_blocks
    rule_blocks.each do |block|
      values = block.scan(/^\*\*([^*\n]+)\*\*\s*\n?(.*?)(?=^\*\*|\z)/m)
      assert_equal FIELDS, values.map(&:first), block.lines.first
      values.each { |name, value| refute_empty value.strip, "#{block.lines.first}: #{name}" }
    end
  end

  def test_contents_links_every_section_in_heading_order
    contents = guide[/^## Inhoudsopgave\n(.*?)(?=^## )/m, 1]
    expected = prose(guide).scan(/^\#{2,6} (.+)$/).flatten.map do |title|
      "[#{title}](##{anchors("## #{title}").first})"
    end
    assert_equal expected, contents.scan(/^ *- (\[.+\]\(#[^)]+\))$/).flatten
  end

  def test_guide_links_and_repository_incoming_links_resolve
    assert_equal anchors(guide).uniq, anchors(guide), 'Duplicate guide anchors'
    links = prose(guide).scan(/\]\(([^)\s]+)\)/).flatten
    links.grep_v(/\A[a-z]+:/).each { |link| assert_local_link(link) }
    %w[AGENTS.md README.md].each { |file| assert_incoming_links(file) }
  end

  def assert_incoming_links(file)
    File.read(File.join(LintTestSupport::ROOT, file)).scan(%r{\]\(\.tools/lint/README\.md#([^)]+)\)}) do |match|
      assert_includes anchors(guide), match.first, "Incoming link from #{file}"
    end
  end

  def assert_local_link(link)
    relative, fragment = link.split('#', 2)
    target = relative.empty? ? GUIDE : File.expand_path(relative, File.dirname(GUIDE))
    assert File.exist?(target), "Missing target: #{link}"
    return unless fragment && File.file?(target) && target.end_with?('.md')

    assert_includes anchors(File.read(target)), fragment, link
  end
end
