# frozen_string_literal: true

module Puma
  class Plugin
    module TelemetryToo
      module Targets
        RSpec.describe OpenTelemetryTarget, :otel_metrics do
          subject(:target) { described_class.new(meter_provider:) }
          let(:meter_provider) { ::OpenTelemetry.meter_provider }
          let(:metric_exporter) { OpenTelemetry::SDK::Metrics::Export::InMemoryMetricPullExporter.new }

          before do
            OpenTelemetry::SDK.configure
            meter_provider.add_metric_reader(metric_exporter)
          end

          it 'creates and records metrics' do
            telemetry = { 'workers.booted' => 1, 'queue.backlog' => 0 }
            target.call(telemetry)

            metric_exporter.pull
            metrics = metric_exporter.metric_snapshots
            booted_metric = metrics.find { |m| m.name == 'workers.booted' }
            backlog_metric = metrics.find { |m| m.name == 'queue.backlog' }

            expect(metrics.size).to eq(2)
            expect(booted_metric).to have_attributes(unit: '{process}', description: be_a(String))
            expect(booted_metric.data_points.last.value).to eq(1)
            expect(backlog_metric).to have_attributes(unit: '{request}', description: be_a(String))
            expect(backlog_metric.data_points.last.value).to eq(0)
          end

          it 'appends specified attributes' do
            target = described_class.new(meter_provider:, attributes: { env: 'production', region: 'us-east' })
            target.call('queue.capacity' => 3)

            metric = metric_exporter.collect.first

            expect(metric.name).to eq('queue.capacity')
            expect(metric.data_points.last).to have_attributes(
              value: 3, attributes: { env: 'production', region: 'us-east' }
            )
          end

          context 'when prefix/suffix are specified' do
            it 'prefixes metric names' do
              target = described_class.new(meter_provider:, prefix: 'custom')
              target.call('workers.total' => 5)

              metric = metric_exporter.collect.first
              expect(metric.name).to eq('custom.workers.total')
              expect(metric.data_points.last.value).to eq(5)
            end

            it 'suffixes metric names' do
              target = described_class.new(meter_provider:, suffix: 'v42')
              target.call('workers.total' => 10)

              metric = metric_exporter.collect.first
              expect(metric.name).to eq('workers.total.v42')
              expect(metric.data_points.last.value).to eq(10)
            end

            it 'applies both prefix and suffix' do
              target = described_class.new(meter_provider:, prefix: 'pre', suffix: 'suf')
              target.call('workers.total' => 2)

              metric = metric_exporter.collect.first
              expect(metric.name).to eq('pre.workers.total.suf')
            end
          end

          context 'when force_flush is enabled' do
            subject(:target) { described_class.new(meter_provider:, force_flush: true) }

            it 'calls force_flush after recording metrics' do
              allow(meter_provider).to receive(:force_flush)

              target.call('workers.spawned_threads' => 3)

              expect(meter_provider).to have_received(:force_flush).once
            end
          end
        end
      end
    end
  end
end
