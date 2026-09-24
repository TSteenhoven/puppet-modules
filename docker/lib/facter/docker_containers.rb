# frozen_string_literal: true

require 'open3'

# Inventory only running containers; application selection belongs to the consuming Puppet code.
Facter.add(:docker_containers) do
  confine kernel: 'Linux'

  setcode do
    docker = '/usr/bin/docker'

    if File.executable?(docker)
      output, status = Open3.capture2(docker, 'ps', '--format', '{{.Names}}', err: File::NULL)
      status.success? ? output.lines.map(&:strip).reject(&:empty?).sort : []
    else
      []
    end
  rescue StandardError
    []
  end
end
