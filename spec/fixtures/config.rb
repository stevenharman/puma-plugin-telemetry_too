# frozen_string_literal: true

app { |_env| [200, {}, ['embedded app']] }
lowlevel_error_handler { |_err| [500, {}, ['error page']] }

threads 1, 1

bind "unix://#{ENV.fetch('BIND_PATH', nil)}"

plugin 'telemetry_too'

Target = Struct.new(:name) do
  def call(telemetry)
    puts "target=#{name} telemetry=#{telemetry.inspect}"
  end
end

Puma::Plugin::TelemetryToo.configure do |config|
  config.add_target Target.new('01')
  config.add_target Target.new('02')
  config.frequency = 0.2
  config.enabled = true
  # Give Puma just enough time to emit the "Ctrl-C" line so we consider the server "started"
  config.initial_delay = 0.01
end
