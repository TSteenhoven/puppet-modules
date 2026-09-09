require_relative 'test_helper'
require 'erb'
require 'tmpdir'
require 'shellwords'

class MonitoringBehaviorTest < Minitest::Test
  # Only fixture executables are exposed as service tools; ordinary text utilities retain their real implementations.
  def run_check(path, scripts:, environment: {}, arguments: [], apt_cache: nil)
    Dir.mktmpdir('puppet-lint-monitoring-') do |directory|
      %w[awk cut grep sort tr sed].each do |command|
        binary, status = Open3.capture2('/bin/sh', '-c', "command -v #{command}")
        raise "Missing test utility #{command}" unless status.success?
        File.symlink(binary.strip, File.join(directory, command))
      end
      scripts.each do |name, content|
        File.write(File.join(directory, name), "#!/bin/sh\n#{content}\n")
        File.chmod(0o700, File.join(directory, name))
      end
      scope = Object.new
      scope.instance_variable_set('@systemd_enable', true)
      scope.instance_variable_set('@admin_config_path_shell', "'/dev/null'")
      scope.instance_variable_set('@apt_settings_file', '/dev/null')
      script = File.join(directory, 'check')
      rendered = ERB.new(File.read(File.join(ProjectLint::ROOT, path)), trim_mode: '-').result(scope.instance_eval { binding })
      # Kernel and hardware reads resolve to an empty fixture tree instead of the test runner's host inventory.
      rendered = rendered.gsub(%r{/(proc|sys)(?=/)}) { "#{directory}/host/#{Regexp.last_match(1)}" }
      if apt_cache
        # Relocate only the persistent cache fixture; no test may create files under the host's /var/cache.
        cache = File.join(directory, 'cache')
        Dir.mkdir(cache)
        File.write(File.join(cache, 'synthetic_1.1.txt'), apt_cache)
        rendered = rendered.sub('CHANGELOG_CACHE_DIR=/var/cache/check_apt/changelogs', "CHANGELOG_CACHE_DIR=#{Shellwords.escape(cache)}")
      end
      File.write(script, rendered)
      stdout, stderr, status = Open3.capture3({ 'PATH' => directory }.merge(environment), '/bin/sh', script, *arguments)
      assert_empty stderr
      [stdout, status.exitstatus]
    end
  end

  def rabbit(queues, limit: 6000, rates: true, active: true)
    commands = {
      'rabbitmqctl' => "printf %s #{Shellwords.escape(queues)}",
      'rabbitmqadmin' => rates ? "printf '0\\t0\\n'" : 'exit 1',
      'systemctl' => active ? 'exit 0' : 'exit 1',
      'ps' => 'exit 0',
    }
    run_check('rabbitmq/templates/check_rabbitmq', scripts: commands, environment: { 'DETAIL_LIMIT' => limit.to_s })
  end

  def test_rabbitmq_preserves_every_queue_until_the_character_limit
    queues = (1..8).map { |number| "queue#{number}\t40\t0\t1\n" }.join
    output, code = rabbit(queues)
    assert_equal 2, code
    assert_includes output, 'queue8 (40 msgs)'
    refute_includes output, 'additional queue(s)'
    assert_includes output.lines.first, 'largest queue1'
    output, code = rabbit(queues, limit: 75)
    assert_equal 2, code
    assert_includes output, 'Long output details truncated'
    assert_operator output.index('Long output details truncated'), :<, output.index('Interpretation:')
    assert_includes output, 'Inspect the listed high or elevated backlog queues first.'
  end

  def test_rabbitmq_preserves_severity_context_and_pipe_sanitization
    [["quiet\t0\t0\t1\n", 0], ["growing\t26\t0\t1\n", 1], ["orphan|queue\t100\t0\t0\n", 0]].each do |queues, expected|
      output, code = rabbit(queues)
      assert_equal expected, code
      assert_equal 1, output.count('|')
      refute_match(/\n\n\n/, output)
      assert_includes output, 'Interpretation:'
    end
    assert_equal 3, rabbit("quiet\t0\t0\t1\n", rates: false).last
    assert_equal 2, rabbit("busy\t40\t0\t1\n", rates: false).last
    output, code = rabbit('', active: false)
    assert_equal 2, code
    assert_includes output.lines.first, 'service is not active'
  end

  def test_nftables_has_one_diagnostic_limit_after_all_filter_addresses
    rules = <<~NFT
      table inet filter {
        set blocked {
          type ipv4_addr
          flags dynamic
        }
        chain input {
          type filter hook input priority filter; policy accept;
          ip saddr @blocked drop
        }
      }
    NFT
    addresses = (1..60).map { |number| "192.0.2.#{number}" }.join(', ')
    command = "case \"$2\" in ruleset) printf %s #{Shellwords.escape(rules)} ;; set) printf %s #{Shellwords.escape("elements = { #{addresses} }")} ;; *) exit 1 ;; esac"
    [6000, 100].each do |limit|
      output, code = run_check('basic_settings/templates/monitoring/check_nftables', scripts: { 'nft' => command, 'systemctl' => 'exit 0' }, environment: { 'DETAIL_LIMIT' => limit.to_s })
      assert_equal 0, code
      assert_includes output, 'Interpretation:'
      if limit == 6000
        assert_includes output, '192.0.2.60'
        refute_includes output, 'truncated'
      else
        assert_includes output, 'Long output details truncated'
      end
    end
  end

  def test_apt_cached_changelog_uses_the_single_character_limit
    changelog = "synthetic (1.1) stable; urgency=medium\n" + (1..2105).map { |number| "entry #{number}\n" }.join
    commands = {
      'apt-get' => "printf '%s\\n' 'Inst synthetic [1.0] (1.1 Debian-Security:12/bookworm-security [amd64])'",
      'apt-cache' => "printf '%s\\n' 'Source: synthetic'",
      'date' => "printf '%s\\n' '1788955200'", 'find' => 'exit 0',
      'mkdir' => 'exit 0', 'stat' => "printf '%s\\n' '1788955200'",
      'timeout' => 'exit 1', 'systemctl' => 'exit 0',
    }
    output, code = run_check('basic_settings/templates/monitoring/check_apt', scripts: commands, environment: { 'DETAIL_LIMIT' => '40000' }, apt_cache: changelog)
    assert_includes [2, 3], code
    assert_includes output, 'entry 2105'
    refute_includes output, 'truncated'
    output, = run_check('basic_settings/templates/monitoring/check_apt', scripts: commands, environment: { 'DETAIL_LIMIT' => '150' }, apt_cache: changelog)
    assert_includes output, 'Long output details truncated'
    assert_operator output.index('Long output details truncated'), :<, output.index('Interpretation:')
  end

  def test_audit_preserves_all_errors_and_keys_before_character_truncation
    commands = {
      'auditctl' => "case \"$1\" in -l) printf '%s\\n' '-w /synthetic' ;; *) printf '%s\\n' 'backlog=0 lost=0 backlog_limit=1000' ;; esac",
      'augenrules' => 'exit 0', 'aureport' => "printf '%s\\n' 'Number of keys: 7'",
      'ausearch' => "printf '%s\\n' #{(1..7).map { |number| Shellwords.escape("key=\"synthetic#{number}\"") }.join(' ')}",
      'journalctl' => "case \"$2\" in -1) printf '%s\\n' 'Linux version synthetic' ;; *) printf '%s\\n' 'error oldest' 'error middle' 'error newer' 'error latest|detail' ;; esac",
      'systemctl' => 'exit 0', 'ps' => 'exit 0', 'uname' => "printf '%s\\n' synthetic", 'date' => "printf '%s\\n' '1788955200'",
    }
    output, code = run_check('basic_settings/templates/monitoring/check_audit', scripts: commands)
    assert_equal 2, code
    assert_includes output, 'error oldest'
    assert_includes output, 'synthetic1'
    assert_equal 1, output.count('|')
    assert_operator output.index('error latest'), :<, output.index('error oldest')
    output, code = run_check('basic_settings/templates/monitoring/check_audit', scripts: commands, environment: { 'DETAIL_LIMIT' => '120' })
    assert_equal 2, code
    assert_includes output, 'Long output details truncated'
    assert_includes output, 'Interpretation:'
  end
end
