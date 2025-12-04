# frozen_string_literal: true

require 'timeout'
require 'net/http'

TestTakesTooLongError = Class.new(StandardError)

module Puma
  class Plugin
    RSpec.describe TelemetryToo do
      around do |example|
        @server = nil

        Timeout.timeout(10, TestTakesTooLongError) do
          example.run
        end
      ensure
        @server&.stop
      end

      before do
        @server = ::Server.new(config)
        @server.start
      end

      context 'when defaults' do
        let(:config) { 'default' }

        it "doesn't run telemetry" do
          expect(@server.lines).to include(/plugin=telemetry msg="disabled, exiting\.\.\."/)
        end
      end

      describe 'with targets' do
        let(:config) { 'config' }
        let(:expected_telemetry) do
          {
            'workers.booted' => 1,
            'workers.total' => 1,
            'workers.spawned_threads' => 1,
            'workers.max_threads' => 1,
            'workers.requests_count' => 0,
            'queue.backlog' => 0,
            'queue.backlog_max' => 0,
            'queue.reactor_max' => 0,
            'queue.capacity' => 1
          }
        end

        it 'runs telemetry' do
          expect(@server.lines).to include(/plugin=telemetry msg="enabled, setting up runner\.\.\."/)
        end

        it 'executes the first target' do
          true until (line = @server.next_line).include?('target=01')
          expect(line).to start_with "target=01 telemetry=#{expected_telemetry.inspect}"
        end

        it 'executes the second target' do
          true until (line = @server.next_line).include?('target=02')
          expect(line).to start_with "target=02 telemetry=#{expected_telemetry.inspect}"
        end
      end

      context 'when subset of telemetry' do
        let(:config) { 'puma_telemetry_subset' }
        let(:expected_telemetry) do
          "{\"queue-backlog\":0,\"workers-spawned_threads\":2,\"workers-max_threads\":4,\"name\":\"Puma::Plugin::TelemetryToo\",\"message\":\"Publish telemetry\"}\n" # rubocop:disable Layout/LineLength
        end

        it 'logs only selected telemetry' do
          true until (line = @server.next_line).include?('Puma::Plugin::TelemetryToo')
          expect(line).to start_with expected_telemetry
        end
      end

      context 'when dogstatsd target' do
        let(:config) { 'dogstatsd' }
        let(:expected_telemetry) do
          %w[
            workers.booted:1|g
            workers.total:1|g
            workers.spawned_threads:1|g
            workers.max_threads:1|g
            workers.requests_count:0|g
            queue.backlog:0|g
            queue.backlog_max:0|g
            queue.reactor_max:0|g
            queue.capacity:1|g
          ]
        end

        it "doesn't crash" do
          true until (line = @server.next_line).include?('DEBUG -- : Statsd')

          lines = ([line.slice(/workers.*/)] + Array.new(8) { @server.next_line.strip })

          expect(lines).to eq(expected_telemetry)
        end
      end

      context 'when open_telemetry target' do
        let(:config) { 'open_telemetry' }
        let(:expected_telemetry) do
          {
            'puma.workers.booted' => 1,
            'puma.workers.total' => 1,
            'puma.workers.spawned_threads' => 1,
            'puma.workers.max_threads' => 1,
            'puma.workers.requests_count' => 0,
            'puma.queue.backlog' => 0,
            'puma.queue.backlog_max' => 0,
            'puma.queue.reactor_max' => 0,
            'puma.queue.capacity' => 1
          }
        end

        it "doesn't crash" do
          matched_telemetry = {}

          while (line = @server.next_line)
            next unless line.include?('OpenTelemetry::SDK::Metrics::State::MetricData')

            metric = JSON.parse(line)
            name = metric.fetch('name')
            value = metric.fetch('value')
            matched_telemetry[name] = value

            break if matched_telemetry.keys.size == expected_telemetry.keys.size
          end

          expect(matched_telemetry).to eq(expected_telemetry)
        end
      end

      context 'when sockets telemetry' do
        let(:config) { 'sockets' }

        def make_request
          Thread.new do
            Net::HTTP.get_response(URI('http://127.0.0.1:59292/'))
          end
        end

        it 'logs socket telemetry' do
          if Gem.loaded_specs['puma'].version >= Gem::Version.new('7.0.0')
            skip('Skipping on Puma >= 7; internals have change and this way of overloading the socket no longer works.')
          end

          # These structs are platform specific, and not available on macOS,
          # for example. If they're undefined, then we cannot capture socket
          # telemetry. We'll skip in that case.
          unless defined?(Socket::SOL_TCP) && defined?(Socket::TCP_INFO)
            skip("Socket::SOL_TCP and/or Socket::TCP_INFO not defined on #{RUBY_PLATFORM}")
          end

          threads = Array.new(2) { make_request }

          sleep 0.1

          threads += Array.new(5) { make_request }

          true while (line = @server.next_line) !~ /sockets.backlog/

          line.strip!

          # either "queue.backlog=1 sockets.backlog=5"
          #     or "queue.backlog=0 sockets.backlog=6"
          #
          # depending on whenever the first 2 requests are
          # pulled at the same time by Puma from backlog
          possible_lines = ['queue.backlog=1 sockets.backlog=5',
                            'queue.backlog=0 sockets.backlog=6']

          expect(possible_lines).to include(line)

          queue_or_socket_backlog = line.split.reject { |kv| kv.include?('_max=') }
          total = queue_or_socket_backlog.sum { |kv| kv.split('=').last.to_i }
          expect(total).to eq(6)

          threads.each(&:join)
        end
      end
    end
  end
end
