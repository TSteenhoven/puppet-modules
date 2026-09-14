# frozen_string_literal: true

require 'json'

# Keep large synthetic tool inputs outside test orchestration, grouped by scenario.
module LintFixtureSupport
  def fixture(key, scenario: name)
    @fixtures ||= JSON.parse(File.read(File.join(__dir__, 'fixtures', "#{self.class::FIXTURE_GROUP}.json")))
    @fixtures.fetch(scenario).fetch(key.to_s)
  end
end
