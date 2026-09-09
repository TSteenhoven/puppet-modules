require_relative 'test_helper'
require 'erb'
require 'tmpdir'
require 'shellwords'

class ShellTemplateTest < Minitest::Test
  # Values mirror Puppet-resolved inputs without including credentials or developer-host facts.
  INPUTS = {
    apt_settings_file: '/etc/apt/apt.conf.d/00-local', agent_bin_dir: '/usr/bin',
    admin_config_path: '/etc/rabbitmq/rabbitmqadmin.conf', check_users_str: 'admin', service: 'ssh',
    interfaces_str: 'eth0', service_str: 'systemd-networkd',
    usb_any_requirements: '', usb_expected: '', usb_whitelist: '',
    memory_available_profiles_spec_shell: "'0:10:5'", swap_free_profiles_spec_shell: "'0:10:5'",
  }.freeze

  MONITORING_TEMPLATES = Dir['*/templates/**/check_*'].freeze

  def render(path, enabled)
    scope = Object.new
    inputs = INPUTS.merge(systemd_enable: enabled)
    %i[check_users_str admin_config_path interfaces_str service_str usb_any_requirements usb_expected usb_whitelist].each { |name| inputs["#{name}_shell"] = Shellwords.escape(inputs.fetch(name)) }
    inputs.each { |key, value| scope.instance_variable_set("@#{key}", value) }
    ERB.new(File.read(path), trim_mode: '-').result(scope.instance_eval { binding })
  end

  def test_monitoring_erb_contains_only_direct_variable_insertion
    MONITORING_TEMPLATES.each do |path|
      File.read(path).scan(/<%(.*?)%>/m).flatten.each do |tag|
        assert_match(/\A=\s*@[a-z_][a-z_0-9]*\s*\z/, tag, "#{path} must keep logic in the shell check")
      end
    end
  end

  def test_configured_shell_inputs_remain_literal_data
    inputs = {
      'ssh/templates/check_ssh' => { 'ALLOWED_USERS' => :check_users_str_shell },
      'rabbitmq/templates/check_rabbitmq' => { 'RABBITMQADMCONF' => :admin_config_path_shell },
      'basic_settings/templates/monitoring/check_network' => { 'IF_LIST' => :interfaces_str_shell, 'SERVICES_LIST' => :service_str_shell },
      'basic_settings/templates/monitoring/check_usb' => { 'ANYREQ_LIST' => :usb_any_requirements_shell, 'EXPECTED_LIST' => :usb_expected_shell, 'WHITELIST_LIST' => :usb_whitelist_shell },
    }
    value = %q(space 'quote' "double" $(printf injected); | *)
    inputs.each do |path, variables|
      variables.each do |variable, input|
        scope = Object.new
        scope.instance_variable_set("@#{input}", Shellwords.escape(value))
        assignment = File.readlines(File.join(ProjectLint::ROOT, path)).find { |line| line.start_with?("#{variable}=") }
        rendered = ERB.new(assignment).result(scope.instance_eval { binding })
        stdout, stderr, status = Open3.capture3('/bin/sh', '-c', rendered + "printf %s \"$#{variable}\"")
        assert status.success?
        assert_empty stderr
        assert_equal value, stdout
      end
    end
  end

  def test_each_monitoring_template_parses_with_and_without_systemd
    refute_empty MONITORING_TEMPLATES
    MONITORING_TEMPLATES.each do |path|
      [false, true].each do |enabled|
        _, _, status = Open3.capture3('/bin/sh', '-n', stdin_data: render(path, enabled))
        assert status.success?, "#{path} must render valid POSIX shell for systemd=#{enabled}"
      end
    end
  end

  def test_missing_systemctl_is_required_only_when_systemd_is_managed
    path = File.join(ProjectLint::ROOT, 'mysql/templates/check_mysql')
    Dir.mktmpdir('puppet-lint-shell-') do |directory|
      # The usage path never executes these binaries, but their presence is part of the check's startup contract.
      %w[awk mysqladmin].each { |name| File.symlink('/usr/bin/true', File.join(directory, name)) }
      script = File.join(directory, 'check')
      File.write(script, render(path, true))
      stdout, _, status = Open3.capture3({ 'PATH' => directory }, '/bin/sh', script, '-h')
      assert_equal 3, status.exitstatus
      assert_includes stdout, 'systemctl not available'
      File.write(script, render(path, false))
      stdout, _, status = Open3.capture3({ 'PATH' => directory }, '/bin/sh', script, '-h')
      assert_equal 3, status.exitstatus
      assert_includes stdout, 'Usage:'
    end
  end

  def test_pam_notification_is_posix_and_only_handles_su_sessions
    script = File.read(File.join(ProjectLint::ROOT, 'basic_settings/templates/login/pam/notify'))
    assert script.start_with?("#!/bin/sh\n")
    _, _, status = Open3.capture3('/bin/sh', '-n', stdin_data: script)
    assert status.success?
    Dir.mktmpdir('puppet-lint-pam-') do |directory|
      # The child shell records its argument; the host's actual profile script is never executed.
      File.write(File.join(directory, 'sh'), "#!/bin/sh\nprintf '%s' \"$1\"\n")
      File.chmod(0o700, File.join(directory, 'sh'))
      ['su', 'sshd'].each do |service|
        stdout, stderr, status = Open3.capture3({ 'PATH' => directory, 'PAM_SERVICE' => service }, '/bin/sh', stdin_data: script)
        assert status.success?
        assert_empty stderr
        assert_equal(service == 'su' ? '/etc/profile.d/99-login-notify.sh' : '', stdout)
      end
    end
  end
end
