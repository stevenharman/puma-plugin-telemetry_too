# frozen_string_literal: true

module Puma
  class Plugin
    module TelemetryToo
      module Targets
        # Target wrapping OpenTelemetry Metrics client.
        #
        # This uses the `gauge` metric type which only exports the last value because
        # the OpenTelemetry exporter aggregates metrics before sending them. Meaning
        # metrics could be published several times before they are flushed via aggregation
        # thread. And when flushed, the last values will be sent.
        #
        # If you need to persist all metrics, you can enable the `force_flush` option.
        # However, force-flushing metrics every time can significantly impact performance.
        #
        # ## Example
        #
        #     require 'opentelemetry-metrics-sdk'
        #
        #     OpenTelemetryTarget.new(meter_provider: OpenTelemetry.meter_provider, prefix: 'puma')
        class OpenTelemetryTarget
          def initialize(meter_provider: ::OpenTelemetry.meter_provider, prefix: nil, suffix: nil,
                         force_flush: false, attributes: {})
            @meter_provider = meter_provider
            @meter          = meter_provider.meter('puma.telemetry')
            @prefix         = prefix
            @suffix         = suffix
            @force_flush    = force_flush
            @attributes     = attributes
            @instruments    = {}
          end

          def call(telemetry)
            telemetry.each do |metric, value|
              instrument(metric).record(value, attributes: attributes)
            end

            meter_provider.force_flush if force_flush?
          end

          def instrument(metric)
            instruments[metric] ||= meter.create_gauge([prefix, metric, suffix].compact.join('.'))
          end

          private

          attr_reader :meter_provider, :meter, :prefix, :suffix, :force_flush, :attributes, :instruments

          def force_flush?
            !!force_flush
          end
        end
      end
    end
  end
end
