# frozen_string_literal: true

require_relative "../../../../spec_helper"

describe Hooks::Plugins::Auth::Base do
  describe ".valid?" do
    let(:payload) { '{"test": "data"}' }
    let(:headers) { { "Content-Type" => "application/json" } }
    let(:config) { { "endpoint" => "/test" } }

    it "raises NotImplementedError by default" do
      expect {
        described_class.valid?(
          payload: payload,
          headers: headers,
          config: config
        )
      }.to raise_error(NotImplementedError, "Validator must implement .valid? class method")
    end

    it "can be subclassed and overridden" do
      test_validator_class = Class.new(described_class) do
        def self.valid?(payload:, headers:, config:)
          # Simple test implementation - always return true
          true
        end
      end

      # Should return true
      result = test_validator_class.valid?(
        payload: payload,
        headers: headers,
        config: config
      )
      expect(result).to be true
    end

    it "accepts different payload types" do
      test_validator_class = Class.new(described_class) do
        def self.valid?(payload:, headers:, config:)
          # Return payload class name for testing
          payload.class.name == "String"
        end
      end

      # Test with string payload
      result = test_validator_class.valid?(
        payload: '{"json": "string"}',
        headers: headers,
        config: config
      )
      expect(result).to be true

      # Test with non-string payload (should be false per our test implementation)
      result = test_validator_class.valid?(
        payload: { json: "hash" },
        headers: headers,
        config: config
      )
      expect(result).to be false
    end

    it "accepts different header types" do
      test_validator_class = Class.new(described_class) do
        def self.valid?(payload:, headers:, config:)
          headers.is_a?(Hash)
        end
      end

      # Test with hash headers
      result = test_validator_class.valid?(
        payload: payload,
        headers: { "X-Test" => "value" },
        config: config
      )
      expect(result).to be true

      # Test with nil headers
      result = test_validator_class.valid?(
        payload: payload,
        headers: nil,
        config: config
      )
      expect(result).to be false
    end

    it "accepts different secret types" do
      # This test is no longer relevant since secrets are fetched internally
      # Instead, test that config types are handled properly
      test_validator_class = Class.new(described_class) do
        def self.valid?(payload:, headers:, config:)
          config.respond_to?(:dig)
        end
      end

      # Test with hash config
      result = test_validator_class.valid?(
        payload: payload,
        headers: headers,
        config: { auth: { secret_env_key: "TEST_SECRET" } }
      )
      expect(result).to be true
    end

    it "accepts different config types" do
      test_validator_class = Class.new(described_class) do
        def self.valid?(payload:, headers:, config:)
          config.is_a?(Hash)
        end
      end

      # Test with hash config
      result = test_validator_class.valid?(
        payload: payload,
        headers: headers,
        config: { "validator" => "test" }
      )
      expect(result).to be true

      # Test with empty hash config
      result = test_validator_class.valid?(
        payload: payload,
        headers: headers,
        config: {}
      )
      expect(result).to be true

      # Test with nil config
      result = test_validator_class.valid?(
        payload: payload,
        headers: headers,
        config: nil
      )
      expect(result).to be false
    end

    it "requires all keyword arguments" do
      expect {
        described_class.valid?(payload: payload, headers: headers)
      }.to raise_error(ArgumentError, /missing keyword.*config/)

      expect {
        described_class.valid?(payload: payload, config: config)
      }.to raise_error(ArgumentError, /missing keyword.*headers/)

      expect {
        described_class.valid?(headers: headers, config: config)
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
        def self.valid?(payload:, headers:, config:)
          true # Always valid for testing
        end
      end

      result = child_class.valid?(
        payload: '{"test": "data"}',
        headers: { "Content-Type" => "application/json" },
        config: { "endpoint" => "/test" }
      )

      expect(result).to be true
    end

    it "subclasses can have different validation logic" do
      test_payload = '{"test": "data"}'
      test_headers = { "Content-Type" => "application/json" }
      test_config = { "endpoint" => "/test" }

      always_valid_class = Class.new(described_class) do
        def self.valid?(payload:, headers:, config:)
          true
        end
      end

      never_valid_class = Class.new(described_class) do
        def self.valid?(payload:, headers:, config:)
          false
        end
      end

      expect(
        always_valid_class.valid?(
          payload: test_payload,
          headers: test_headers,
          config: test_config
        )
      ).to be true

      expect(
        never_valid_class.valid?(
          payload: test_payload,
          headers: test_headers,
          config: test_config
        )
      ).to be false
    end
  end

  describe "documentation compliance" do
    it "has the expected public interface" do
      expect(described_class.methods).to include(:valid?, :log, :stats, :failbot, :fetch_secret, :find_header_value)
    end

    it "valid? method accepts the documented parameters" do
      method = described_class.method(:valid?)
      expect(method.parameters).to include([:keyreq, :payload])
      expect(method.parameters).to include([:keyreq, :headers])
      expect(method.parameters).to include([:keyreq, :config])
    end
  end

  describe ".find_header_value" do
    it "finds header value with case-insensitive matching" do
      headers = { "Content-Type" => "application/json", "X-Test" => "value" }

      expect(described_class.find_header_value(headers, "content-type")).to eq("application/json")
      expect(described_class.find_header_value(headers, "CONTENT-TYPE")).to eq("application/json")
      expect(described_class.find_header_value(headers, "x-test")).to eq("value")
      expect(described_class.find_header_value(headers, "X-TEST")).to eq("value")
    end

    it "returns nil for missing headers" do
      headers = { "Content-Type" => "application/json" }

      expect(described_class.find_header_value(headers, "Missing-Header")).to be_nil
      expect(described_class.find_header_value(headers, "")).to be_nil
      expect(described_class.find_header_value(headers, nil)).to be_nil
    end

    it "handles invalid headers object" do
      expect(described_class.find_header_value(nil, "Content-Type")).to be_nil
      expect(described_class.find_header_value("not a hash", "Content-Type")).to be_nil
      expect(described_class.find_header_value(123, "Content-Type")).to be_nil
    end

    it "converts non-string values to strings" do
      headers = { "X-Count" => 42, "X-Boolean" => true }

      expect(described_class.find_header_value(headers, "X-Count")).to eq("42")
      expect(described_class.find_header_value(headers, "x-boolean")).to eq("true")
    end

    it "handles headers with symbol keys" do
      headers = { :content_type => "application/json", "X-Test" => "value" }

      expect(described_class.find_header_value(headers, "content_type")).to eq("application/json")
      expect(described_class.find_header_value(headers, "x-test")).to eq("value")
    end
  end

  describe "global component access" do
    describe ".log" do
      it "provides access to global log" do
        expect(described_class.log).to be(Hooks::Log.instance)
      end
    end

    describe ".stats" do
      it "provides access to global stats" do
        expect(described_class.stats).to be_a(Hooks::Plugins::Instruments::Stats)
        expect(described_class.stats).to eq(Hooks::Core::GlobalComponents.stats)
      end
    end

    describe ".failbot" do
      it "provides access to global failbot" do
        expect(described_class.failbot).to be_a(Hooks::Plugins::Instruments::Failbot)
        expect(described_class.failbot).to eq(Hooks::Core::GlobalComponents.failbot)
      end
    end

    it "allows stats and failbot usage in subclasses" do
      test_auth_class = Class.new(described_class) do
        def self.valid?(payload:, headers:, config:)
          stats.increment("auth.validation", { plugin: "TestAuth" })

          # Simulate validation failure
          if headers["Authorization"].nil?
            failbot.report("Missing authorization header", { plugin: "TestAuth" })
            return false
          end

          true
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

        # Test with authorization header (should pass)
        result = test_auth_class.valid?(
          payload: '{"test": "data"}',
          headers: { "Authorization" => "Bearer token" },
          config: {}
        )
        expect(result).to be true
        expect(collected_data).to include(
          { type: :stats, action: :increment, metric: "auth.validation", tags: { plugin: "TestAuth" } }
        )

        # Test without authorization header (should fail and report error)
        collected_data.clear
        result = test_auth_class.valid?(
          payload: '{"test": "data"}',
          headers: {},
          config: {}
        )
        expect(result).to be false
        expect(collected_data).to match_array([
          { type: :stats, action: :increment, metric: "auth.validation", tags: { plugin: "TestAuth" } },
          { type: :failbot, action: :report, message: "Missing authorization header", context: { plugin: "TestAuth" } }
        ])
      ensure
        Hooks::Core::GlobalComponents.stats = original_stats
        Hooks::Core::GlobalComponents.failbot = original_failbot
      end
    end
  end
end
