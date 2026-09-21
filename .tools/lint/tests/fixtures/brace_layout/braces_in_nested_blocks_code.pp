# Check whether this service runs a Node.js application.
if ('ExecStart' in $service and $service['ExecStart'] =~ String and $service['ExecStart'] =~ /^(?:node|\.{1,2}\/node|\/(?:[^\/\s]+\/)+node)\s+/) { # lint:ignore:140chars

  # Require a working directory for the dependency audit.
  if ('WorkingDirectory' in $service and $service['WorkingDirectory'] =~ String) {

    basic_settings::monitoring_npm_audit { 'synthetic':
      dir => $service['WorkingDirectory'],
    }
  }
}
