# frozen_string_literal: true

require 'debug/prelude'
require 'opentelemetry/sdk'
require 'opentelemetry-metrics-sdk'

# Adapt the standard ConsoleMetricPullExporter to add force_flush behavior for our testing
module ::OpenTelemetry
  module SDK
    module Metrics
      module Export
        class JsonConsoleMetricExporter < ::OpenTelemetry::SDK::Metrics::Export::ConsoleMetricPullExporter
          def force_flush(*)
            pull
          end

          def export(metrics, timeout: nil) # rubocop:disable Lint/UnusedMethodArgument
            return FAILURE if @stopped

            Array(metrics).each do |metric|
              data = metric.to_h
              data[:type] = metric.class.name
              data[:value] = metric.data_points.last.value

              puts JSON.dump(data)
            end

            SUCCESS
          end
        end
      end
    end
  end
end

OpenTelemetry::SDK.configure

console_metric_exporter = OpenTelemetry::SDK::Metrics::Export::JsonConsoleMetricExporter.new
OpenTelemetry.meter_provider.add_metric_reader(console_metric_exporter)

app { |_env| [200, {}, ['embedded app']] }
lowlevel_error_handler { |_err| [500, {}, ['error page']] }

# Configure Puma and load the plugin
threads(1, 1)
bind("unix://#{ENV.fetch('BIND_PATH')}")
plugin('telemetry_too')

Puma::Plugin::TelemetryToo.configure do |config|
  config.add_target :open_telemetry, meter_provider: OpenTelemetry.meter_provider, force_flush: true
  config.frequency = 0.2
  config.enabled = true
  # Give Puma just enough time to emit the "Ctrl-C" line so we consider the server "started"
  config.initial_delay = 0.01
end
