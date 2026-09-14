# frozen_string_literal: true

require 'optparse'

# Redirect option-file reads only in the synthetic CLI subprocess.
module SyntheticLintConfiguration
  ROOT = ENV.fetch('SYNTHETIC_LINT_CONFIG_ROOT')

  # Substitute a local fixture for the system option file.
  module OptionFiles
    def load(path)
      path = File.join(ROOT, 'system.rc') if path == '/etc/puppet-lint.rc'
      super
    end
  end

  # Provide a synthetic home without changing account settings or HOME.
  module HomeDirectory
    def home(*)
      ROOT
    end
  end

  # Resolve the explicit home-relative option path into the fixture directory.
  module HomePath
    def expand_path(path, *arguments)
      return File.join(ROOT, 'personal.rc') if path == '~/.puppet-lint.rc'

      super
    end
  end
end

OptionParser.prepend(SyntheticLintConfiguration::OptionFiles)
Dir.singleton_class.prepend(SyntheticLintConfiguration::HomeDirectory)
File.singleton_class.prepend(SyntheticLintConfiguration::HomePath)
