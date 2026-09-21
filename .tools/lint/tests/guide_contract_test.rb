# frozen_string_literal: true

require_relative 'test_helper'
require_relative 'guide_links_support'

# Check the guide's bounded technical structure against the loaded public interfaces.
class GuideContractTest < Minitest::Test
  include LintTestSupport
  include ProjectLint::GuideLinks

  GUIDE = File.join(LintTestSupport::ROOT, '.tools/lint/README.md')
  RULES = %w[docs/CODE_RULES.md docs/DOCUMENTATION_RULES.md docs/OPERATIONAL_RULES.md].freeze
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

  def test_registry_activation_matches_both_profiles
    repository = profile_checks('.puppet-lint.rc')
    shared = profile_checks('.tools/lint/config/puppet-lint.rc')
    registry.each do |row|
      check = row.first.delete('`')
      assert_equal repository.fetch(check) ? 'Ja' : 'Nee', row[1], check
      assert_equal shared.fetch(check) ? 'Ja' : 'Nee', row[2], check
    end
  end

  def test_registry_links_point_to_authoritative_rules
    registry.each do |row|
      check = row.first.delete('`')
      row.values_at(3, 5).each { |cell| assert_registry_links(cell, check) }
      assert_registry_links(row[4], check) if row[4].include?('](')
    end
  end

  def assert_registry_links(cell, check)
    links = cell.scan(/\]\(([^)]*)\)/).flatten
    refute_empty links, "Missing rule links for #{check}"
    links.each do |link|
      path, anchor = link.split('#', 2)
      assert_includes RULES, path, check
      target = File.join(File.dirname(GUIDE), path)
      assert_path_exists target
      assert_includes anchors(File.read(target)), anchor, check
    end
  end

  def rule_blocks
    RULES.flat_map do |name|
      chapter = File.read(File.join(File.dirname(GUIDE), name)).sub(/^## Inhoudsopgave\n.*?(?=^## )/m, '')
      prose(chapter).split(/(?=^\#{2,3} )/).drop(1).reject { |block| block.include?('<!-- lint-rule-group -->') }
    end
  end

  def test_rules_have_unique_authoritative_headings
    headings = rule_blocks.map { |block| block.lines.first.sub(/^\#+ /, '').strip }
    duplicates = headings.tally.select { |_heading, count| count > 1 }
    assert_empty duplicates, 'Rules duplicated across authoritative documents'
  end

  def test_each_rule_has_all_nonempty_fields_in_order
    refute_empty rule_blocks
    rule_blocks.each do |block|
      values = block.scan(/^\*\*([^*\n]+)\*\*\s*\n?(.*?)(?=^\*\*|\z)/m)
      assert_equal FIELDS, values.map(&:first), block.lines.first
      values.each { |name, value| refute_empty value.strip, "#{block.lines.first}: #{name}" }
    end
  end
end
