# frozen_string_literal: true

module Helpers
  module OtelMetrics
    # Clear SDK configuration state between tests
    #
    # NOTE: This should eventually be provided by the opentelemetry-test-helpers Gem
    # see: https://github.com/open-telemetry/opentelemetry-ruby/blob/main/test_helpers/lib/opentelemetry/test_helpers.rb
    def reset_metrics_sdk
      require 'opentelemetry-metrics-sdk'

      OpenTelemetry.instance_variable_set(
        :@meter_provider,
        OpenTelemetry::Internal::ProxyMeterProvider.new
      )
      OpenTelemetry::SDK::Metrics::ForkHooks.instance_variable_set(:@fork_hooks_attached, false)
      OpenTelemetry.logger = Logger.new(File::NULL)
      OpenTelemetry.error_handler = nil
    end
  end
end
