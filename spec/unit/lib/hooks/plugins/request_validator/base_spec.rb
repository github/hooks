# frozen_string_literal: true

require_relative "../../../../spec_helper"

describe Hooks::Plugins::RequestValidator::Base do
  describe ".valid?" do
    let(:payload) { '{"test": "data"}' }
    let(:headers) { { "Content-Type" => "application/json" } }
    let(:secret) { "test_secret" }
    let(:config) { { "endpoint" => "/test" } }

    it "raises NotImplementedError by default" do
      expect {
        described_class.valid?(
          payload: payload,
          headers: headers,
          secret: secret,
          config: config
        )
      }.to raise_error(NotImplementedError, "Validator must implement .valid? class method")
    end

    it "can be subclassed and overridden" do
      test_validator_class = Class.new(described_class) do
        def self.valid?(payload:, headers:, secret:, config:)
          # Simple test implementation - check if secret is present
          !secret.nil? && !secret.empty?
        end
      end

      # Should return true with valid secret
      result = test_validator_class.valid?(
        payload: payload,
        headers: headers,
        secret: "valid_secret",
        config: config
      )
      expect(result).to be true

      # Should return false with empty secret
      result = test_validator_class.valid?(
        payload: payload,
        headers: headers,
        secret: "",
        config: config
      )
      expect(result).to be false

      # Should return false with nil secret
      result = test_validator_class.valid?(
        payload: payload,
        headers: headers,
        secret: nil,
        config: config
      )
      expect(result).to be false
    end

    it "accepts different payload types" do
      test_validator_class = Class.new(described_class) do
        def self.valid?(payload:, headers:, secret:, config:)
          # Return payload class name for testing
          payload.class.name == "String"
        end
      end

      # Test with string payload
      result = test_validator_class.valid?(
        payload: '{"json": "string"}',
        headers: headers,
        secret: secret,
        config: config
      )
      expect(result).to be true

      # Test with non-string payload (should be false per our test implementation)
      result = test_validator_class.valid?(
        payload: { json: "hash" },
        headers: headers,
        secret: secret,
        config: config
      )
      expect(result).to be false
    end

    it "accepts different header types" do
      test_validator_class = Class.new(described_class) do
        def self.valid?(payload:, headers:, secret:, config:)
          headers.is_a?(Hash)
        end
      end

      # Test with hash headers
      result = test_validator_class.valid?(
        payload: payload,
        headers: { "X-Test" => "value" },
        secret: secret,
        config: config
      )
      expect(result).to be true

      # Test with nil headers
      result = test_validator_class.valid?(
        payload: payload,
        headers: nil,
        secret: secret,
        config: config
      )
      expect(result).to be false
    end

    it "accepts different secret types" do
      test_validator_class = Class.new(described_class) do
        def self.valid?(payload:, headers:, secret:, config:)
          secret.respond_to?(:to_s)
        end
      end

      # Test with string secret
      result = test_validator_class.valid?(
        payload: payload,
        headers: headers,
        secret: "string_secret",
        config: config
      )
      expect(result).to be true

      # Test with symbol secret
      result = test_validator_class.valid?(
        payload: payload,
        headers: headers,
        secret: :symbol_secret,
        config: config
      )
      expect(result).to be true

      # Test with number secret
      result = test_validator_class.valid?(
        payload: payload,
        headers: headers,
        secret: 12345,
        config: config
      )
      expect(result).to be true
    end

    it "accepts different config types" do
      test_validator_class = Class.new(described_class) do
        def self.valid?(payload:, headers:, secret:, config:)
          config.is_a?(Hash)
        end
      end

      # Test with hash config
      result = test_validator_class.valid?(
        payload: payload,
        headers: headers,
        secret: secret,
        config: { "validator" => "test" }
      )
      expect(result).to be true

      # Test with empty hash config
      result = test_validator_class.valid?(
        payload: payload,
        headers: headers,
        secret: secret,
        config: {}
      )
      expect(result).to be true

      # Test with nil config
      result = test_validator_class.valid?(
        payload: payload,
        headers: headers,
        secret: secret,
        config: nil
      )
      expect(result).to be false
    end

    it "requires all keyword arguments" do
      expect {
        described_class.valid?(payload: payload, headers: headers, secret: secret)
      }.to raise_error(ArgumentError, /missing keyword.*config/)

      expect {
        described_class.valid?(payload: payload, headers: headers, config: config)
      }.to raise_error(ArgumentError, /missing keyword.*secret/)

      expect {
        described_class.valid?(payload: payload, secret: secret, config: config)
      }.to raise_error(ArgumentError, /missing keyword.*headers/)

      expect {
        described_class.valid?(headers: headers, secret: secret, config: config)
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
        def self.valid?(payload:, headers:, secret:, config:)
          true # Always valid for testing
        end
      end

      result = child_class.valid?(
        payload: '{"test": "data"}',
        headers: { "Content-Type" => "application/json" },
        secret: "test_secret",
        config: { "endpoint" => "/test" }
      )

      expect(result).to be true
    end

    it "subclasses can have different validation logic" do
      test_payload = '{"test": "data"}'
      test_headers = { "Content-Type" => "application/json" }
      test_secret = "test_secret"
      test_config = { "endpoint" => "/test" }

      always_valid_class = Class.new(described_class) do
        def self.valid?(payload:, headers:, secret:, config:)
          true
        end
      end

      never_valid_class = Class.new(described_class) do
        def self.valid?(payload:, headers:, secret:, config:)
          false
        end
      end

      expect(
        always_valid_class.valid?(
          payload: test_payload,
          headers: test_headers,
          secret: test_secret,
          config: test_config
        )
      ).to be true

      expect(
        never_valid_class.valid?(
          payload: test_payload,
          headers: test_headers,
          secret: test_secret,
          config: test_config
        )
      ).to be false
    end
  end

  describe "documentation compliance" do
    it "has the expected public interface" do
      expect(described_class.methods(false)).to include(:valid?)
    end

    it "valid? method accepts the documented parameters" do
      method = described_class.method(:valid?)
      expect(method.parameters).to include([:keyreq, :payload])
      expect(method.parameters).to include([:keyreq, :headers])
      expect(method.parameters).to include([:keyreq, :secret])
      expect(method.parameters).to include([:keyreq, :config])
    end
  end
end