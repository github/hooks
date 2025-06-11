# frozen_string_literal: true

require_relative "../../lib/hooks"
require "rack/test"
require "json"
require "fileutils"
require "tmpdir"
require "yaml"

RSpec.describe "Global Lifecycle Hooks Integration" do
  include Rack::Test::Methods

  def app
    @app ||= Hooks.build(config: config_hash)
  end
  let(:temp_config_dir) { Dir.mktmpdir("config") }
  let(:temp_lifecycle_dir) { Dir.mktmpdir("lifecycle_plugins") }
  let(:temp_handler_dir) { Dir.mktmpdir("handler_plugins") }
  let(:temp_endpoints_dir) { Dir.mktmpdir("endpoints") }

  let(:config_hash) do
    {
      lifecycle_plugin_dir: temp_lifecycle_dir,
      handler_plugin_dir: temp_handler_dir,
      endpoints_dir: temp_endpoints_dir,
      log_level: "info",
      root_path: "/webhooks",
      health_path: "/health",
      version_path: "/version",
      environment: "development"
    }
  end

  before do
    # Create a test lifecycle plugin
    lifecycle_plugin_content = <<~RUBY
      class TestingLifecycle < Hooks::Plugins::Lifecycle
        @@events = []

        def self.events
          @@events
        end

        def self.clear_events
          @@events = []
        end

        def on_request(env)
          @@events << {
            type: :request,
            path: env["PATH_INFO"],
            method: env["REQUEST_METHOD"],
            handler: env["hooks.handler"]
          }
        end

        def on_response(env, response)
          @@events << {
            type: :response,
            path: env["PATH_INFO"],
            response: response,
            handler: env["hooks.handler"]
          }
        end

        def on_error(exception, env)
          @@events << {
            type: :error,
            path: env["PATH_INFO"],
            error: exception.class.name,
            message: exception.message,
            handler: env["hooks.handler"]
          }
        end
      end
    RUBY
    File.write(File.join(temp_lifecycle_dir, "testing_lifecycle.rb"), lifecycle_plugin_content)

    # Create a test handler plugin that uses stats and failbot
    handler_plugin_content = <<~RUBY
      class IntegrationTestHandler < Hooks::Plugins::Handlers::Base
        def call(payload:, headers:, config:)
          stats.increment("handler.called", { handler: "IntegrationTestHandler" })

          if payload&.dig("should_fail")
            failbot.report("Intentional test failure", { payload: })
            raise StandardError, "Test failure requested"
          end

          {
            status: "success",
            handler: "IntegrationTestHandler",
            timestamp: Time.now.iso8601,
            payload_received: !payload.nil?
          }
        end
      end
    RUBY
    File.write(File.join(temp_handler_dir, "integration_test_handler.rb"), handler_plugin_content)

    # Create an endpoint configuration
    endpoint_config_content = <<~YAML
      path: /integration-test
      handler: IntegrationTestHandler
    YAML
    File.write(File.join(temp_endpoints_dir, "integration_test.yml"), endpoint_config_content)
  end

  after do
    FileUtils.rm_rf(temp_config_dir)
    FileUtils.rm_rf(temp_lifecycle_dir)
    FileUtils.rm_rf(temp_handler_dir)
    FileUtils.rm_rf(temp_endpoints_dir)

    # Clean up any test classes
    Object.send(:remove_const, :TestingLifecycle) if defined?(TestingLifecycle)
    Object.send(:remove_const, :IntegrationTestHandler) if defined?(IntegrationTestHandler)
  end

  it "integrates lifecycle hooks with handler execution and global components" do
    # Set up custom stats and failbot to capture events
    captured_stats = []
    captured_failbot = []

    custom_stats = Class.new(Hooks::Core::Stats) do
      def initialize(collector)
        @collector = collector
      end

      def increment(metric_name, tags = {})
        @collector << { action: :increment, metric: metric_name, tags: }
      end
    end

    custom_failbot = Class.new(Hooks::Core::Failbot) do
      def initialize(collector)
        @collector = collector
      end

      def report(error_or_message, context = {})
        @collector << { action: :report, message: error_or_message, context: }
      end
    end

    original_stats = Hooks::Core::GlobalComponents.stats
    original_failbot = Hooks::Core::GlobalComponents.failbot

    begin
      Hooks::Core::GlobalComponents.stats = custom_stats.new(captured_stats)
      Hooks::Core::GlobalComponents.failbot = custom_failbot.new(captured_failbot)

      # Force reload to ensure our plugin is loaded
      load File.join(temp_lifecycle_dir, "testing_lifecycle.rb")

      # Verify the lifecycle plugin was loaded
      expect(defined?(TestingLifecycle)).to be_truthy
      TestingLifecycle.clear_events

      # Test successful request
      post "/webhooks/integration-test", { "test" => "data" }.to_json, { "CONTENT_TYPE" => "application/json" }

      expect(last_response.status).to eq(200)
      response_data = JSON.parse(last_response.body)
      expect(response_data["status"]).to eq("success")
      expect(response_data["handler"]).to eq("IntegrationTestHandler")

      # Check that stats were recorded
      expect(captured_stats).to include(
        { action: :increment, metric: "handler.called", tags: { handler: "IntegrationTestHandler" } }
      )

      # Check that lifecycle plugins are available
      expect(Hooks::Core::PluginLoader.lifecycle_plugins).not_to be_empty

    ensure
      Hooks::Core::GlobalComponents.stats = original_stats
      Hooks::Core::GlobalComponents.failbot = original_failbot
    end
  end
end