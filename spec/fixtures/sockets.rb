# frozen_string_literal: true

@initial_delay = true

app do |_env|
  sleep(2) if @initial_delay

  # there's only 1 thread, so it should be fine
  @initial_delay = false

  [200, {}, ['embedded app']]
end

lowlevel_error_handler { |_err| [500, {}, ['error page']] }

threads 1, 1
plugin 'telemetry_too'

bind "unix://#{ENV.fetch('BIND_PATH')}"
bind 'tcp://localhost:59292'

Puma::Plugin::TelemetryToo.configure do |config|
  # Simple `key=value` formatter
  config.add_target(:io, formatter: ->(t) { t.map { |r| r.join('=') }.join(' ') }, transform: :passthrough)
  config.frequency = 1
  config.enabled = true

  # Check how `queue.backlog` from puma behaves
  # Consider adding new _max stats: 'queue.backlog_max', 'queue.reactor_max'
  config.puma_telemetry = ['queue.backlog']

  # Give Puma just enough time to emit the "Ctrl-C" line so we consider the server "started"
  config.initial_delay = 0.01

  config.socket_telemetry!
end
