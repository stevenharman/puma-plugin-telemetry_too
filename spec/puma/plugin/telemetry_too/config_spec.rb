# frozen_string_literal: true

module Puma
  class Plugin
    module TelemetryToo
      RSpec.describe Config do
        subject(:config) { described_class.new }

        describe '#enabled?' do
          context 'when default' do
            it { expect(config.enabled?).to eq false }
          end

          context 'when enabled' do
            before { config.enabled = true }

            it { expect(config.enabled?).to eq true }
          end
        end

        describe '#add_target' do
          context 'when built in: IO' do
            it 'adds new IO Target' do
              expect { config.add_target(:io) }.to change(config.targets, :size).by(1)
              expect(config.targets.first).to be_a(TelemetryToo::Targets::IOTarget)
            end
          end

          context 'when built in: Datadog' do
            let(:client) { instance_double('statsd') }

            it 'adds new Datadog target' do
              expect { config.add_target(:dogstatsd, client: client) }.to change(config.targets, :size).by(1)
              expect(config.targets.first).to be_a(TelemetryToo::Targets::DatadogStatsdTarget)
            end
          end

          context 'when custom' do
            let(:target) { proc { |telemetry| puts telemetry.inspect } }

            it 'adds new Custom Target' do
              expect { config.add_target(target) }.to change(config.targets, :size).by(1)
              expect(config.targets.first).to be_a(Proc)
            end
          end

          context 'when multiple targets' do
            it 'adds new targets' do
              expect do
                config.add_target(proc { |telemetry| puts telemetry.inspect })
                config.add_target(:io)
                config.add_target(:io)
              end.to change(config.targets, :size).by(3)
            end
          end
        end
      end
    end
  end
end
