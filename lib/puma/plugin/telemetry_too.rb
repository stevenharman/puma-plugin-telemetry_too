# frozen_string_literal: true

require 'puma'
require 'puma/plugin'

require 'puma/plugin/telemetry_too/version'
require 'puma/plugin/telemetry_too/data'
require 'puma/plugin/telemetry_too/targets/datadog_statsd_target'
require 'puma/plugin/telemetry_too/targets/io_target'
require 'puma/plugin/telemetry_too/targets/log_target'
require 'puma/plugin/telemetry_too/config'

module Puma
  class Plugin
    # TelemetryToo plugin for puma, supporting:
    #
    # - multiple targets, decide where to push puma telemetry information, i.e. datadog, cloudwatch, logs
    # - filtering, select which metrics are interesting for you, extend when necessery
    #
    module TelemetryToo
      class Error < StandardError; end

      class << self
        attr_writer :config

        def config
          @config ||= Config.new
        end

        def configure
          yield(config)
        end

        def build(launcher = nil)
          socket_telemetry(puma_telemetry, launcher)
        end

        private

        def puma_telemetry
          stats = ::Puma.stats_hash
          data_class = if stats.key?(:workers)
                         ClusteredData
                       else
                         WorkerData
                       end
          data_class
            .new(stats)
            .metrics(config.puma_telemetry)
        end

        def socket_telemetry(telemetry, launcher)
          return telemetry if launcher.nil?
          return telemetry unless config.socket_telemetry?

          telemetry.merge! SocketData.new(launcher.binder.ios, config.socket_parser)
                                     .metrics

          telemetry
        end
      end

      # Contents of actual Puma Plugin
      #
      module PluginInstanceMethods
        def start(launcher)
          @launcher = launcher

          unless Puma::Plugin::TelemetryToo.config.enabled?
            log_writer.log 'plugin=telemetry msg="disabled, exiting..."'
            return
          end

          log_writer.log 'plugin=telemetry msg="enabled, setting up runner..."'

          in_background do
            sleep Puma::Plugin::TelemetryToo.config.initial_delay
            run!
          end
        end

        def run!
          loop do
            log_writer.debug 'plugin=telemetry msg="publish"'

            call(Puma::Plugin::TelemetryToo.build(@launcher))
          rescue Errno::EPIPE
            # Occurs when trying to output to STDOUT while puma is shutting down
          rescue StandardError => e
            log_writer.error "plugin=telemetry err=#{e.class} msg=#{e.message.inspect}"
          ensure
            sleep Puma::Plugin::TelemetryToo.config.frequency
          end
        end

        def call(telemetry)
          Puma::Plugin::TelemetryToo.config.targets.each do |target|
            target.call(telemetry)
          end
        end

        private

        def log_writer
          if Puma::Const::PUMA_VERSION.to_i < 6
            @launcher.events
          else
            @launcher.log_writer
          end
        end
      end
    end
  end
end

Puma::Plugin.create do
  include Puma::Plugin::TelemetryToo::PluginInstanceMethods
end
