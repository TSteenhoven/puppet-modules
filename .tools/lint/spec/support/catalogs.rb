require 'puppet'
require 'tmpdir'
require 'json'

module ProjectLint
  # Synthetic platform facts keep catalog compilation independent of the developer host and production data.
  module Catalogs
    def self.facts(os: 'Debian', release: '12', secure_boot: false)
      codenames = { '11' => 'bullseye', '12' => 'bookworm', '13' => 'trixie', '22.04' => 'jammy', '23.04' => 'lunar', '24.04' => 'noble', '26.04' => 'resolute' }
      {
        'networking' => { 'fqdn' => 'host.example.org', 'hostname' => 'host', 'domain' => 'example.org', 'ip' => '192.0.2.10', 'interfaces' => { 'eth0' => { 'ip' => '192.0.2.10' } } },
        'os' => { 'family' => 'Debian', 'name' => os, 'architecture' => 'amd64', 'release' => { 'major' => release, 'full' => release }, 'distro' => { 'codename' => codenames.fetch(release), 'id' => os, 'release' => { 'major' => release, 'full' => release } } },
        'kernel' => 'Linux', 'kernelrelease' => '6.1.0-amd64', 'architecture' => 'amd64', 'is_virtual' => true, 'virtual' => 'kvm', 'secure_boot_enabled' => secure_boot,
        'processors' => { 'count' => 2, 'physicalcount' => 1, 'models' => ['Synthetic CPU'] },
        'memory' => { 'system' => { 'total_bytes' => 8589934592, 'available_bytes' => 6442450944 }, 'swap' => { 'total_bytes' => 1073741824 } },
        'disks' => {}, 'mountpoints' => { '/' => { 'filesystem' => 'ext4', 'device' => '/dev/sda1' } },
        'dmi' => { 'manufacturer' => 'Synthetic', 'product' => { 'name' => 'Synthetic host' } },
      }
    end

    # PAL compiles and validates resources only; neither catalog application nor script execution is exposed.
    def self.compile(code, root: ProjectLint::ROOT, platform: facts)
      Dir.mktmpdir('puppet-lint-catalog-') do |temporary|
        Puppet.initialize_settings(['--confdir', temporary, '--vardir', temporary, '--logdir', temporary, '--rundir', temporary, '--certname', 'host.example.org']) unless Puppet.settings.app_defaults_initialized?
        Puppet::Pal.in_tmp_environment('lint', modulepath: [root, ProjectLint::ROOT].uniq, facts: platform) do |pal|
          pal.with_catalog_compiler(code_string: code) { |compiler| return compiler.catalog_data_hash }
        end
      end
    end

    def self.resource(catalog, type, title)
      found = catalog.fetch('resources').find { |entry| entry['type'] == type && entry['title'] == title }
      raise "Missing expected #{type} resource in synthetic catalog" unless found

      found.fetch('parameters', {})
    end

    def self.normalized(catalog)
      {
        'resources' => catalog.fetch('resources').map { |resource| resource.reject { |key, _| %w[file line].include?(key) } }.sort_by { |resource| [resource['type'], resource['title']] },
        'edges' => catalog.fetch('edges').sort_by { |edge| [edge['source'], edge['target']] },
      }
    end

    # Expand containment and autorequires without applying resources. Explicit Linux providers prevent the
    # developer's macOS defaults from rejecting Debian/Ubuntu attributes during graph construction.
    # A search path in this graph-only copy lets legacy unqualified exec guards be represented too;
    # this checks ordering, not command-provider correctness or command execution.
    def self.relationship_graph(catalog)
      providers = { 'Package' => 'apt', 'Service' => 'systemd', 'User' => 'useradd', 'Group' => 'groupadd' }
      resources = catalog.fetch('resources').map do |resource|
        parameters = resource.fetch('parameters', {}).dup
        parameters['provider'] ||= providers[resource['type']] if providers.key?(resource['type'])
        parameters['path'] ||= ['/usr/bin', '/bin', '/usr/sbin', '/sbin'] if resource['type'] == 'Exec'
        resource.merge('parameters' => parameters)
      end
      Puppet::Resource::Catalog.from_data_hash(catalog.merge('resources' => resources)).to_ral.relationship_graph
    end
  end
end
