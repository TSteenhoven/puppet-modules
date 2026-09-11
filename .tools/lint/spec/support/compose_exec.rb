require 'rbconfig'
require 'shellwords'

module ProjectLint
  # Execute rendered Docker exec commands locally with synthetic IDs, arguments and environment only.
  module ComposeExec
    def self.write_docker(path)
      File.write(path, "#!#{RbConfig.ruby}\n" + <<~'RUBY')
        require 'json'
        if ENV['TEST_DOCKER_CALLS']
          File.open(ENV['TEST_DOCKER_CALLS'], 'a') { |file| file.puts JSON.dump(ARGV) }
        end
        case ARGV.shift
        when 'ps'
          puts ENV.fetch('TEST_DOCKER_CONTAINERS', 'aabbccddeeff')
          exit Integer(ENV.fetch('TEST_DOCKER_PS_STATUS', '0'))
        when 'exec'
          File.write(ENV['TEST_DOCKER_ARGS'], JSON.dump(['exec', *ARGV])) if ENV['TEST_DOCKER_ARGS']
          environment = {}
          while ARGV.first&.start_with?('-')
            case ARGV.shift
            when '--env'
              key, value = ARGV.shift.split('=', 2)
              environment[key] = value
            when '-i'
              # The caller's shell supplies stdin; this substitute preserves that descriptor.
            else
              abort 'unexpected Docker exec option'
            end
          end
          abort 'invalid synthetic container ID' unless ARGV.shift&.match?(/\A[0-9a-f]+\z/i)
          exec(environment, *ARGV)
        else
          abort 'unexpected Docker operation'
        end
      RUBY
      File.chmod(0o700, path)
    end

    def self.command(parameters, docker, key = 'command')
      parameters.fetch(key).gsub('/usr/bin/docker', Shellwords.escape(docker))
    end
  end
end
