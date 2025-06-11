# frozen_string_literal: true

require "simplecov"
require "simplecov-erb"
require "rspec"
require "time"
require_relative "required_coverage_percentage"

TIME_MOCK = "2025-01-01T00:00:00Z"
FAKE_HMAC_SECRET = "octoawesome-secret"
FAKE_ALT_HMAC_SECRET = "octoawesome-2-secret"

ENV["GITHUB_WEBHOOK_SECRET"] = FAKE_HMAC_SECRET
ENV["ALT_WEBHOOK_SECRET"] = FAKE_ALT_HMAC_SECRET

COV_DIR = File.expand_path("../../coverage", File.dirname(__FILE__))

SimpleCov.root File.expand_path("../..", File.dirname(__FILE__))
SimpleCov.coverage_dir COV_DIR

SimpleCov.minimum_coverage REQUIRED_COVERAGE_PERCENTAGE

SimpleCov.at_exit do
  File.write("#{COV_DIR}/total-coverage.txt", SimpleCov.result.covered_percent)
  SimpleCov.result.format!
end

SimpleCov.start do
  add_filter "config/"
  add_filter "spec/"
  add_filter "vendor/gems/"
end

# Require all Ruby files in the lib directory
Dir.glob(File.expand_path("../../lib/**/*.rb", __dir__)).each do |file|
  require file
end

# Initialize plugins for tests
Hooks::Core::PluginLoader.load_all_plugins({
  auth_plugin_dir: nil,
  handler_plugin_dir: nil
})

RSpec.configure do |config|
  config.before(:each) do
    fake_time = Time.parse(TIME_MOCK)
    allow(Time).to receive(:now).and_return(fake_time)
    allow(Time).to receive(:new).and_return(fake_time)
    allow(Time).to receive(:iso8601).and_return(fake_time)
    allow(fake_time).to receive(:utc).and_return(fake_time)
    allow(fake_time).to receive(:iso8601).and_return(TIME_MOCK)

    allow(Kernel).to receive(:sleep)
    allow_any_instance_of(Kernel).to receive(:sleep)
    allow_any_instance_of(Object).to receive(:sleep)
  end
end
