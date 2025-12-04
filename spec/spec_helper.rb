# frozen_string_literal: true

require 'debug/prelude'
require 'bundler/setup'
require 'puma/plugin/telemetry_too'

require_relative 'support/server'
require_relative 'support/otel_metrics_helpers'

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = '.rspec_status'

  # Run specs in random order to surface order dependencies. If you find an
  # order dependency and want to debug it, you can fix the order by providing
  # the seed, which is printed after each run.
  #     --seed 1234
  config.order = :random

  # Seed global randomization in this process using the `--seed` CLI option.
  # Setting this allows you to use `--seed` to deterministically reproduce
  # test failures related to randomization by passing the same `--seed` value
  # as the one that triggered the failure.
  Kernel.srand config.seed

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end

  # Do not abort on the first failure of an expectation within an example.
  config.define_derived_metadata do |meta|
    meta[:aggregate_failures] = true
  end

  config.around(:each, :otel_metrics) do |example|
    reset_metrics_sdk
    example.run
    reset_metrics_sdk
  end

  config.include Helpers::OtelMetrics, otel_metrics: true
end
