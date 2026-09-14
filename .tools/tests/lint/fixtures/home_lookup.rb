# frozen_string_literal: true

# Redirect only the subprocess's home lookup to synthetic personal configuration.
module SyntheticLintHome
  def expand_path(path, *arguments)
    return File.join(Dir.home, '.puppet-lint.rc') if path == '~/.puppet-lint.rc'

    super
  end

  # Leave the test runner's and account's home directories untouched.
  module Directory
    def home(*)
      ENV.fetch('SYNTHETIC_LINT_HOME')
    end
  end
end

Dir.singleton_class.prepend(SyntheticLintHome::Directory)
File.singleton_class.prepend(SyntheticLintHome)
