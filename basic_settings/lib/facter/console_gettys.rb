# frozen_string_literal: true

require 'open3'
require 'shellwords'

Facter.add(:console_gettys) do
  confine kernel: 'Linux'
  setcode do
    output, status = Open3.capture2('systemctl', 'show', 'getty.target', '--property=Wants', '--property=Requires')
    raise "systemctl show getty.target failed (exit #{status.exitstatus})" unless status.success?

    wants = output[/^Wants=(.*)$/, 1]
    requires = output[/^Requires=(.*)$/, 1]
    raise 'Missing Wants or Requires property for getty.target' unless wants && requires

    # Decode systemctl's shell quoting while retaining the escapes that belong to the unit names themselves.
    Shellwords.split("#{wants} #{requires}")
              .grep(/\A(?:getty|serial-getty)@(?:[\w:.-]|\\x[\da-fA-F]{2})+\.service\z/)
              .reject { |unit| unit == 'getty@tty\x2a.service' }.uniq.sort
  rescue StandardError => e
    { 'error' => e.message }
  end
end
