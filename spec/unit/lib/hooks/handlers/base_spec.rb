# frozen_string_literal: true

describe Hooks::Plugins::Handlers::Base do
  describe "#call" do
    let(:handler) { described_class.new }
    let(:payload) { { "data" => "test" } }
    let(:headers) { { "Content-Type" => "application/json" } }
    let(:config) { { "endpoint" => "/test" } }
    let(:env) do
      {
        "REQUEST_METHOD" => "GET",
        "hooks.request_id" => "fake-request-id",
      }
    end

    it "raises NotImplementedError by default" do
      expect {
        handler.call(payload: payload, headers: headers, env: env, config: config)
      }.to raise_error(NotImplementedError, "Handler must implement #call method")
    end

    it "can be subclassed and overridden" do
      test_handler_class = Class.new(described_class) do
        def call(payload:, headers:, env:, config:)
          {
            received_payload: payload,
            received_headers: headers,
            received_config: config,
            status: "success"
          }
        end
      end

      handler = test_handler_class.new
      result = handler.call(payload: payload, headers: headers, env: env, config: config)

      expect(result).to eq({
        received_payload: payload,
        received_headers: headers,
        received_config: config,
        status: "success"
      })
    end

    it "accepts different payload types" do
      test_handler_class = Class.new(described_class) do
        def call(payload:, headers:, env:, config:)
          { payload_class: payload.class.name }
        end
      end

      handler = test_handler_class.new

      # Test with hash
      result = handler.call(payload: { "test" => "data" }, headers: headers, env: env, config: config)
      expect(result[:payload_class]).to eq("Hash")

      # Test with string
      result = handler.call(payload: "raw string", headers: headers, env: env, config: config)
      expect(result[:payload_class]).to eq("String")

      # Test with nil
      result = handler.call(payload: nil, headers: headers, env: env, config: config)
      expect(result[:payload_class]).to eq("NilClass")
    end

    it "accepts different header types" do
      test_handler_class = Class.new(described_class) do
        def call(payload:, headers:, env:, config:)
          { headers_received: headers }
        end
      end

      handler = test_handler_class.new

      # Test with hash
      headers_hash = { "User-Agent" => "test", "X-Custom" => "value" }
      result = handler.call(payload: payload, headers: headers_hash, env: env, config: config)
      expect(result[:headers_received]).to eq(headers_hash)

      # Test with empty hash
      result = handler.call(payload: payload, headers: {}, env: env, config: config)
      expect(result[:headers_received]).to eq({})

      # Test with nil
      result = handler.call(payload: payload, headers: nil, env: env, config: config)
      expect(result[:headers_received]).to be_nil
    end

    it "accepts different config types" do
      test_handler_class = Class.new(described_class) do
        def call(payload:, headers:, env:, config:)
          { config_received: config }
        end
      end

      handler = test_handler_class.new

      # Test with complex config
      complex_config = {
        "endpoint" => "/test",
        "opts" => { "timeout" => 30 },
        "handler" => "TestHandler"
      }
      result = handler.call(payload: payload, headers: headers, env: env, config: complex_config)
      expect(result[:config_received]).to eq(complex_config)

      # Test with empty config
      result = handler.call(payload: payload, headers: headers, env: env, config: {})
      expect(result[:config_received]).to eq({})
    end

    it "requires all keyword arguments" do
      expect {
        handler.call(payload: payload, headers: headers, env: env)
      }.to raise_error(ArgumentError, /missing keyword.*config/)

      expect {
        handler.call(payload: payload, env: env, config: config)
      }.to raise_error(ArgumentError, /missing keyword.*headers/)

      expect {
        handler.call(headers: headers, env: env, config: config)
      }.to raise_error(ArgumentError, /missing keyword.*payload/)
    end
  end

  describe "inheritance" do
    it "can be inherited" do
      child_class = Class.new(described_class)
      expect(child_class.ancestors).to include(described_class)
    end

    it "maintains method signature in subclasses" do
      child_class = Class.new(described_class) do
        def call(payload:, headers:, env:, config:)
          "child implementation"
        end
      end

      handler = child_class.new
      result = handler.call(
        payload: { "test" => "data" },
        headers: { "Content-Type" => "application/json" },
        env: { "REQUEST_METHOD" => "POST", "hooks.request_id" => "test-id" },
        config: { "endpoint" => "/test" }
      )

      expect(result).to eq("child implementation")
    end
  end

  describe "documentation compliance" do
    it "has the expected public interface" do
      expect(described_class.instance_methods).to include(:call, :log, :stats, :failbot)
    end

    it "call method accepts the documented parameters" do
      method = described_class.instance_method(:call)
      expect(method.parameters).to include([:keyreq, :payload])
      expect(method.parameters).to include([:keyreq, :headers])
      expect(method.parameters).to include([:keyreq, :config])
    end
  end

  describe "global component access" do
    let(:handler) { described_class.new }

    describe "#log" do
      it "provides access to global log" do
        expect(handler.log).to be(Hooks::Log.instance)
      end
    end

    describe "#stats" do
      it "provides access to global stats" do
        expect(handler.stats).to be_a(Hooks::Plugins::Instruments::Stats)
        expect(handler.stats).to eq(Hooks::Core::GlobalComponents.stats)
      end
    end

    describe "#failbot" do
      it "provides access to global failbot" do
        expect(handler.failbot).to be_a(Hooks::Plugins::Instruments::Failbot)
        expect(handler.failbot).to eq(Hooks::Core::GlobalComponents.failbot)
      end
    end

    it "allows stats and failbot usage in subclasses" do
      test_handler_class = Class.new(described_class) do
        def call(payload:, headers:, env:, config:)
          stats.increment("handler.called", { handler: "TestHandler" })

          if payload.nil?
            failbot.report("Payload is nil", { handler: "TestHandler" })
          end

          { status: "processed" }
        end
      end

      # Create custom components for testing
      collected_data = []

      custom_stats = Class.new(Hooks::Core::Stats) do
        def initialize(collector)
          @collector = collector
        end

        def increment(metric_name, tags = {})
          @collector << { type: :stats, action: :increment, metric: metric_name, tags: }
        end
      end

      custom_failbot = Class.new(Hooks::Core::Failbot) do
        def initialize(collector)
          @collector = collector
        end

        def report(error_or_message, context = {})
          @collector << { type: :failbot, action: :report, message: error_or_message, context: }
        end
      end

      original_stats = Hooks::Core::GlobalComponents.stats
      original_failbot = Hooks::Core::GlobalComponents.failbot

      begin
        Hooks::Core::GlobalComponents.stats = custom_stats.new(collected_data)
        Hooks::Core::GlobalComponents.failbot = custom_failbot.new(collected_data)

        handler = test_handler_class.new

        # Test with non-nil payload
        handler.call(payload: { "test" => "data" }, headers: {}, env: {}, config: {})
        expect(collected_data).to include(
          { type: :stats, action: :increment, metric: "handler.called", tags: { handler: "TestHandler" } }
        )

        # Test with nil payload
        collected_data.clear
        handler.call(payload: nil, headers: {}, env: {}, config: {})
        expect(collected_data).to match_array([
          { type: :stats, action: :increment, metric: "handler.called", tags: { handler: "TestHandler" } },
          { type: :failbot, action: :report, message: "Payload is nil", context: { handler: "TestHandler" } }
        ])
      ensure
        Hooks::Core::GlobalComponents.stats = original_stats
        Hooks::Core::GlobalComponents.failbot = original_failbot
      end
    end
  end

  describe "#error!" do
    let(:handler) { described_class.new }

    it "raises a handler error with default status 500" do
      expect {
        handler.error!("Something went wrong")
      }.to raise_error(Hooks::Plugins::Handlers::Error) do |error|
        expect(error.body).to eq("Something went wrong")
        expect(error.status).to eq(500)
      end
    end

    it "raises a handler error with custom status" do
      expect {
        handler.error!({ error: "validation_failed", message: "Invalid input" }, 400)
      }.to raise_error(Hooks::Plugins::Handlers::Error) do |error|
        expect(error.body).to eq({ error: "validation_failed", message: "Invalid input" })
        expect(error.status).to eq(400)
      end
    end

    it "can be called from subclasses" do
      test_handler = Class.new(described_class) do
        def call(payload:, headers:, env:, config:)
          error!("Custom error from subclass", 422)
        end
      end

      handler = test_handler.new
      expect {
        handler.call(payload: {}, headers: {}, env: {}, config: {})
      }.to raise_error(Hooks::Plugins::Handlers::Error) do |error|
        expect(error.body).to eq("Custom error from subclass")
        expect(error.status).to eq(422)
      end
    end
  end
end
