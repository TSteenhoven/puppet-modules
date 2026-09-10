require_relative 'test_helper'
require_relative 'support/catalogs'
require 'fileutils'
require 'digest'

class MonitoringCatalogTest < Minitest::Test
  def test_nginx_delegates_backend_selection_and_preserves_registration_lifecycle
    Dir.mktmpdir('monitoring_backend_catalog_') do |directory|
      source = File.join(ProjectLint::ROOT, 'basic_settings')
      target = File.join(directory, 'basic_settings')
      FileUtils.mkdir_p(File.join(target, 'manifests'))
      Dir.children(source).reject { |name| name == 'manifests' }.each do |name|
        File.symlink(File.join(source, name), File.join(target, name))
      end
      Dir.children(File.join(source, 'manifests')).reject { |name| name == 'monitoring.pp' }.each do |name|
        File.symlink(File.join(source, 'manifests', name), File.join(target, 'manifests', name))
      end
      # Widen only this isolated fixture's input type to simulate a future backend, without implementing one.
      monitoring = File.read(File.join(source, 'manifests/monitoring.pp'))
      File.write(File.join(target, 'manifests/monitoring.pp'), monitoring.sub("Enum['none', 'openitcockpit']", 'String'))

      cases = [
        ['openitcockpit', 'present', true, 'present'],
        ['synthetic_backend', 'present', true, 'present'],
        ['none', 'present', true, 'absent'],
        ['openitcockpit', 'absent', true, 'absent'],
        ['openitcockpit', 'present', false, 'absent'],
      ]
      cases.each do |backend, state, enabled, expected|
        # Supply the shared directory contract that a real additional backend would have to implement.
        location = backend == 'synthetic_backend' ? "file { 'monitoring_location_plugins': path => '/tmp/synthetic-monitoring-plugins', ensure => directory }" : ''
        catalog = ProjectLint::Catalogs.compile(<<~PUPPET, root: directory)
          class { 'basic_settings::monitoring': package => '#{backend}' }
          #{location}
          include nginx
          nginx::server { 'synthetic':
            ensure => '#{state}',
            monitoring_cert => #{enabled},
            https_enable => true,
            server_name => 'app.example.org',
            redirect_from => 'www.example.org',
            ssl_certificate => '/etc/nginx/synthetic.crt',
            ssl_certificate_key => '/etc/nginx/synthetic.key',
            php_fpm_enable => false,
          }
        PUPPET
        %w[main redirect].each do |kind|
          title = "synthetic/#{kind}"
          helper = ProjectLint::Catalogs.resource(catalog, 'Nginx::Monitoring_cert', title)
          registration = ProjectLint::Catalogs.resource(catalog, 'Basic_settings::Monitoring_custom', "nginx_cert_#{Digest::SHA256.hexdigest(title)}")
          assert_equal expected, helper['ensure'], [backend, state, enabled, kind].inspect
          assert_equal expected, registration['ensure'], [backend, state, enabled, kind].inspect
          assert_equal 'nginx_cert', registration['script']
          if expected == 'present'
            assert_includes registration['cmd'], '-f /etc/nginx/conf.d/synthetic.conf'
          else
            assert_nil registration['cmd']
          end
        end
      end
    end
  end
end
