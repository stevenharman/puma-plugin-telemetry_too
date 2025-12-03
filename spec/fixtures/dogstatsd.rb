# frozen_string_literal: true

app { |_env| [200, {}, ['embedded app']] }
lowlevel_error_handler { |_err| [500, {}, ['error page']] }

threads 1, 1

bind "unix://#{ENV.fetch('BIND_PATH', nil)}"

plugin 'telemetry_too'

require 'datadog/statsd'
require 'logger'

Puma::Plugin::TelemetryToo.configure do |config|
  config.add_target :dogstatsd, client: Datadog::Statsd.new(logger: Logger.new($stdout))
  config.frequency = 0.2
  config.enabled = true
  # Give Puma just enough time to emit the "Ctrl-C" line so we consider the server "started"
  config.initial_delay = 0.01
end
