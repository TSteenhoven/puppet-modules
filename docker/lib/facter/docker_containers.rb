# frozen_string_literal: true

require 'open3'

# Inventory running containers in the local rootful daemon's default data directory.
# Paths include a trailing slash; application selection and file management belong to Puppet.
Facter.add(:docker_containers) do
  confine kernel: 'Linux'

  setcode do
    docker = '/usr/bin/docker'

    if File.executable?(docker)
      output, status = Open3.capture2(docker, 'ps', '--no-trunc', '--format', '{{.ID}} {{.Names}}', err: File::NULL)
      if status.success?
        output.lines.each_with_object({}) do |line, containers|
          id, name = line.strip.split(/\s+/, 2)
          next if id.nil? || name.nil?

          containers[name] = { 'path' => "/var/lib/docker/containers/#{id}/" }
        end
      else
        {}
      end
    else
      {}
    end
  rescue StandardError
    {}
  end
end
