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
        #     OpenTelemetryTarget.new(meter_provider: OpenTelemetry.meter_provider, prefix: 'webserver')
        class OpenTelemetryTarget
          def initialize(meter_provider: ::OpenTelemetry.meter_provider, prefix: 'puma', suffix: nil,
                         force_flush: false, attributes: {})
            @meter_provider = meter_provider
            @meter = meter_provider.meter('puma.telemetry')
            @prefix = prefix
            @suffix = suffix
            @force_flush = force_flush
            @attributes  = attributes
            @instruments = {}
            @mutex = Mutex.new
          end

          def call(telemetry)
            telemetry.each do |metric, value|
              instrument(metric).record(value, attributes: attributes)
            end

            meter_provider.force_flush if force_flush?
          end

          def instrument(metric)
            mutex.synchronize do
              instruments[metric] ||= create_gauge(metric)
            end
          end

          private

          attr_reader :meter_provider, :meter, :prefix, :suffix, :force_flush, :attributes, :instruments, :mutex

          def create_gauge(metric)
            meta = META_DATA.fetch(metric, MetaData.new(unit: 1, description: nil))
            meter.create_gauge([prefix, metric, suffix].compact.join('.'),
                               unit: String(meta.unit), description: String(meta.description))
          end

          def force_flush?
            !!force_flush
          end

          MetaData = Data.define(:unit, :description)
          private_constant :MetaData

          # rubocop:disable Metrics/LineLength
          META_DATA = {
            'workers.booted' => MetaData[unit: '{process}', description: 'Number of booted Puma workers (processes).'],
            'workers.total' => MetaData[unit: '{process}', description: 'Total number of Puma workers (processes).'],
            'workers.spawned_threads' => MetaData[unit: '{thread}', description: 'Number of spawned threads across all Puma workers.'],
            'workers.max_threads' => MetaData[unit: '{thread}', description: 'Maximum number of threads Puma is configured to spawn, across all workers.'],
            'workers.requests_count' => MetaData[unit: '{request}', description: 'Total number of requests handled by all Puma workers, since start.'],
            'queue.backlog' => MetaData[unit: '{request}', description: 'Requests that are waiting for an available thread.'],
            'queue.backlog_max' => MetaData[unit: '{request}', description: "Maximum number of requests that have been fully buffered by the reactor and placed in a ready queue, but have not yet been picked up by a server thread. This stat is reset on every call, so it's the maximum value observed since the last stat call."],
            'queue.reactor_max' => MetaData[unit: '{request}', description: "Maximum observed number of requests held in Puma's reactor. This stat is reset on every call, so it's the maximum value observed since the last stat call."],
            'queue.capacity' => MetaData[unit: '{thread}', description: 'Number of Threads waiting to receive work.'],
            'sockets.backlog' => MetaData[unit: '{request}', description: 'Number of unacknowledged connections in the Sockets Puma is bound to.']

          }.freeze
          private_constant :META_DATA
          # rubocop:enable Metrics/LineLength
        end
      end
    end
  end
end
