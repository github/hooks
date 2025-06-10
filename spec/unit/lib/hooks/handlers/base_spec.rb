# frozen_string_literal: true

require_relative "../../../spec_helper"

describe Hooks::Handlers::Base do
  describe "#call" do
    let(:handler) { described_class.new }
    let(:payload) { { "data" => "test" } }
    let(:headers) { { "Content-Type" => "application/json" } }
    let(:config) { { "endpoint" => "/test" } }

    it "raises NotImplementedError by default" do
      expect {
        handler.call(payload: payload, headers: headers, config: config)
      }.to raise_error(NotImplementedError, "Handler must implement #call method")
    end

    it "can be subclassed and overridden" do
      test_handler_class = Class.new(described_class) do
        def call(payload:, headers:, config:)
          {
            received_payload: payload,
            received_headers: headers,
            received_config: config,
            status: "success"
          }
        end
      end

      handler = test_handler_class.new
      result = handler.call(payload: payload, headers: headers, config: config)

      expect(result).to eq({
        received_payload: payload,
        received_headers: headers,
        received_config: config,
        status: "success"
      })
    end

    it "accepts different payload types" do
      test_handler_class = Class.new(described_class) do
        def call(payload:, headers:, config:)
          { payload_class: payload.class.name }
        end
      end

      handler = test_handler_class.new

      # Test with hash
      result = handler.call(payload: { "test" => "data" }, headers: headers, config: config)
      expect(result[:payload_class]).to eq("Hash")

      # Test with string
      result = handler.call(payload: "raw string", headers: headers, config: config)
      expect(result[:payload_class]).to eq("String")

      # Test with nil
      result = handler.call(payload: nil, headers: headers, config: config)
      expect(result[:payload_class]).to eq("NilClass")
    end

    it "accepts different header types" do
      test_handler_class = Class.new(described_class) do
        def call(payload:, headers:, config:)
          { headers_received: headers }
        end
      end

      handler = test_handler_class.new

      # Test with hash
      headers_hash = { "User-Agent" => "test", "X-Custom" => "value" }
      result = handler.call(payload: payload, headers: headers_hash, config: config)
      expect(result[:headers_received]).to eq(headers_hash)

      # Test with empty hash
      result = handler.call(payload: payload, headers: {}, config: config)
      expect(result[:headers_received]).to eq({})

      # Test with nil
      result = handler.call(payload: payload, headers: nil, config: config)
      expect(result[:headers_received]).to be_nil
    end

    it "accepts different config types" do
      test_handler_class = Class.new(described_class) do
        def call(payload:, headers:, config:)
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
      result = handler.call(payload: payload, headers: headers, config: complex_config)
      expect(result[:config_received]).to eq(complex_config)

      # Test with empty config
      result = handler.call(payload: payload, headers: headers, config: {})
      expect(result[:config_received]).to eq({})
    end

    it "requires all keyword arguments" do
      expect {
        handler.call(payload: payload, headers: headers)
      }.to raise_error(ArgumentError, /missing keyword.*config/)

      expect {
        handler.call(payload: payload, config: config)
      }.to raise_error(ArgumentError, /missing keyword.*headers/)

      expect {
        handler.call(headers: headers, config: config)
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
        def call(payload:, headers:, config:)
          "child implementation"
        end
      end

      handler = child_class.new
      result = handler.call(
        payload: { "test" => "data" },
        headers: { "Content-Type" => "application/json" },
        config: { "endpoint" => "/test" }
      )

      expect(result).to eq("child implementation")
    end
  end

  describe "documentation compliance" do
    it "has the expected public interface" do
      expect(described_class.instance_methods(false)).to include(:call)
    end

    it "call method accepts the documented parameters" do
      method = described_class.instance_method(:call)
      expect(method.parameters).to include([:keyreq, :payload])
      expect(method.parameters).to include([:keyreq, :headers])
      expect(method.parameters).to include([:keyreq, :config])
    end
  end
end