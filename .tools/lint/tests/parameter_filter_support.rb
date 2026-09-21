# frozen_string_literal: true

# Shared synthetic interfaces for filter predicate and receiving-default diagnostics.
module ParameterFilterSupport
  def forwarding(default: '7', predicate: '$item != 7', entries: "'value' => $source")
    <<~PUPPET
      define example::receiver (Any $value = #{default}) {}
      define example::sender (Any $source = #{default}) {
        $settings = { #{entries} }.filter |$key, $item| { #{predicate} }
        example::receiver { $name: * => $settings }
      }
    PUPPET
  end
end
