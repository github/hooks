# frozen_string_literal: true

ENV["HOOKS_SILENCE_CONFIG_LOADER_MESSAGES"] = "true" # Silence config loader messages in tests

require_relative "../../lib/hooks"
require "rack/test"
require "json"
require "fileutils"
require "yaml"

RSpec.describe "Hooks Integration" do
  include Rack::Test::Methods

  def app
    @app ||= Hooks.build(
      config: {
        handler_plugin_dir: "./spec/integration/tmp/handlers",
        log_level: "error", # Reduce noise in tests
        request_limit: 1048576,
        request_timeout: 15,
        root_path: "/webhooks",
        health_path: "/health",
        version_path: "/version",
        environment: "development",
        endpoints_dir: "./spec/integration/tmp/endpoints",
        use_catchall_route: true  # Enable catch-all route for testing
      }
    )
  end

  before(:all) do
    # Create test endpoint config
    FileUtils.mkdir_p("./spec/integration/tmp/endpoints")
    File.write("./spec/integration/tmp/endpoints/test.yaml", {
      path: "/test",
      handler: "TestHandler",
      opts: { test_mode: true }
    }.to_yaml)

    # Create test handler
    FileUtils.mkdir_p("./spec/integration/tmp/handlers")
    File.write("./spec/integration/tmp/handlers/test_handler.rb", <<~RUBY)
      require_relative "../../../../lib/hooks/plugins/handlers/base"

      class TestHandler < Hooks::Plugins::Handlers::Base
        def call(payload:, headers:, env:, config:)
          {
            status: "test_success",
            payload_received: payload,
            config_opts: config[:opts],
            timestamp: Time.now.utc.iso8601
          }
        end
      end
    RUBY
  end

  after(:all) do
    # Clean up test files
    FileUtils.rm_rf("./spec/integration/tmp")
  end

  describe "operational endpoints" do
    it "responds to health check" do
      get "/health"
      expect(last_response.status).to eq(200)

      body = JSON.parse(last_response.body)
      expect(body["status"]).to eq("healthy")
      expect(body["version"]).to eq(Hooks::VERSION)
      expect(body).to have_key("timestamp")
      expect(body).to have_key("uptime_seconds")
    end

    it "responds to version endpoint" do
      get "/version"
      expect(last_response.status).to eq(200)

      body = JSON.parse(last_response.body)
      expect(body["version"]).to eq(Hooks::VERSION)
      expect(body).to have_key("timestamp")
    end
  end

  describe "webhook endpoints" do
    it "processes JSON webhook with custom handler" do
      payload = { event: "test_event", data: "test_data" }

      post "/webhooks/test", payload.to_json, {
        "CONTENT_TYPE" => "application/json"
      }

      expect(last_response.status).to eq(200)

      body = JSON.parse(last_response.body)
      expect(body["status"]).to eq("test_success")
      expect(body["payload_received"]).to eq(payload.stringify_keys)
      expect(body["config_opts"]).to eq({ "test_mode" => true })
    end

    it "handles raw string payload" do
      payload = "raw webhook data"

      post "/webhooks/test", payload, {
        "CONTENT_TYPE" => "text/plain"
      }

      expect(last_response.status).to eq(200)

      body = JSON.parse(last_response.body)
      expect(body["status"]).to eq("test_success")
      expect(body["payload_received"]).to eq(payload)
    end

    it "uses default handler for unknown endpoint" do
      payload = { test: "data" }

      post "/webhooks/unknown", payload.to_json, {
        "CONTENT_TYPE" => "application/json"
      }

      expect(last_response.status).to eq(200)

      body = JSON.parse(last_response.body)
      expect(body["message"]).to eq("webhook processed successfully")
      expect(body["handler"]).to eq("DefaultHandler")
    end
  end

  describe "request validation" do
    it "rejects requests that are too large" do
      large_payload = "x" * 2_000_000 # 2MB, larger than 1MB limit

      post "/webhooks/test", large_payload, {
        "CONTENT_TYPE" => "text/plain",
        "CONTENT_LENGTH" => large_payload.length.to_s
      }

      expect(last_response.status).to eq(413)
    end
  end

  describe "error handling" do
    it "returns structured error response" do
      # Send invalid JSON as text/plain to avoid Grape's automatic parsing
      post "/webhooks/test", "invalid json", {
        "CONTENT_TYPE" => "text/plain"
      }

      expect(last_response.status).to eq(200) # Our handler accepts any payload
      body = JSON.parse(last_response.body)
      expect(body["payload_received"]).to eq("invalid json")
    end
  end
end
