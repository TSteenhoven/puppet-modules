# frozen_string_literal: true

require 'builder'

module ProjectLint
  # Shared XML envelope; each producer defines its own cases and exit status.
  module JunitReport
    def self.write(output, name:, **counts)
      xml = Builder::XmlMarkup.new(indent: 2)
      xml.instruct!
      xml.testsuites do
        xml.testsuite(name: name, **counts) { yield xml }
      end
      output.write(xml.target!)
    end
  end
end
