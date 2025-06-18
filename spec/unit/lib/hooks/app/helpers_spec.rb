# frozen_string_literal: true

require "tempfile"
require "json"
require_relative "../../../spec_helper"

describe Hooks::App::Helpers do
  let(:test_class) do
    Class.new do
      include Hooks::App::Helpers

      attr_accessor :headers, :env, :request_obj

      def headers
        @headers ||= {}
      end

      def env
        @env ||= {}
      end

      def request
        @request_obj
      end

      def error!(message, code)
        raise StandardError, "#{code}: #{message.to_json}"
      end
    end
  end

  let(:helper) { test_class.new }

  describe "#uuid" do
    it "generates a valid UUID" do
      result = helper.uuid

      expect(result).to match(/\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/)
    end

    it "generates unique UUIDs on each call" do
      uuid1 = helper.uuid
      uuid2 = helper.uuid

      expect(uuid1).not_to eq(uuid2)
    end
  end

  describe "#enforce_request_limits" do
    let(:config) { { request_limit: 1000 } }

    context "with content-length in headers" do
      it "passes when content length is within limit" do
        helper.headers["Content-Length"] = "500"

        expect { helper.enforce_request_limits(config) }.not_to raise_error
      end

      it "raises error when content length exceeds limit" do
        helper.headers["Content-Length"] = "1500"
        request_context = { request_id: "test-request-id" }

        error = nil
        begin
          helper.enforce_request_limits(config, request_context)
        rescue StandardError => e
          error = e
        end

        expect(error).to be_a(StandardError)
        expect(error.message).to start_with("413: ")
        body = error.message.sub("413: ", "")
        parsed = JSON.parse(body)
        expect(parsed).to eq({ "error" => "request_body_too_large", "message" => "request body too large", "request_id" => "test-request-id" })
      end
    end

    context "with different header formats" do
      it "handles uppercase CONTENT_LENGTH" do
        helper.headers["CONTENT_LENGTH"] = "1500"

        expect { helper.enforce_request_limits(config) }.to raise_error(StandardError, /413.*too large/)
      end

      it "handles lowercase content-length" do
        helper.headers["content-length"] = "1500"

        expect { helper.enforce_request_limits(config) }.to raise_error(StandardError, /413.*too large/)
      end

      it "handles HTTP_CONTENT_LENGTH" do
        helper.headers["HTTP_CONTENT_LENGTH"] = "1500"

        expect { helper.enforce_request_limits(config) }.to raise_error(StandardError, /413.*too large/)
      end
    end

    context "with content-length in env" do
      it "uses env CONTENT_LENGTH when headers are empty" do
        helper.env["CONTENT_LENGTH"] = "1500"

        expect { helper.enforce_request_limits(config) }.to raise_error(StandardError, /413.*too large/)
      end

      it "uses env HTTP_CONTENT_LENGTH when headers are empty" do
        helper.env["HTTP_CONTENT_LENGTH"] = "1500"

        expect { helper.enforce_request_limits(config) }.to raise_error(StandardError, /413.*too large/)
      end
    end

    context "with request object" do
      it "uses request.content_length when available" do
        request_mock = double("request")
        allow(request_mock).to receive(:content_length).and_return(1500)
        helper.request_obj = request_mock

        expect { helper.enforce_request_limits(config) }.to raise_error(StandardError, /413.*too large/)
      end
    end

    context "without content length information" do
      it "passes when no content length is available" do
        expect { helper.enforce_request_limits(config) }.not_to raise_error
      end
    end
  end

  describe "#parse_payload" do
    context "with JSON content" do
      it "parses valid JSON with application/json content type" do
        headers = { "Content-Type" => "application/json" }
        body = '{"key": "value"}'

        result = helper.parse_payload(body, headers)

        expect(result).to eq({ "key" => "value" })
      end

      it "parses JSON that looks like JSON without content type" do
        headers = {}
        body = '{"key": "value"}'

        result = helper.parse_payload(body, headers)

        expect(result).to eq({ "key" => "value" })
      end

      it "parses JSON arrays" do
        headers = {}
        body = '[{"key": "value"}]'

        result = helper.parse_payload(body, headers)

        expect(result).to eq([{ "key" => "value" }])
      end

      it "does not symbolize keys by default" do
        headers = { "Content-Type" => "application/json" }
        body = '{"string_key": "value", "nested": {"inner_key": "inner_value"}}'

        result = helper.parse_payload(body, headers)

        expect(result).to eq({
          "string_key" => "value",
          "nested" => { "inner_key" => "inner_value" }
        })
      end

      it "does not symbolize keys when symbolize is false" do
        headers = { "Content-Type" => "application/json" }
        body = '{"string_key": "value"}'

        result = helper.parse_payload(body, headers, symbolize: false)

        expect(result).to eq({ "string_key" => "value" })
      end
    end

    context "with different content type headers" do
      it "handles uppercase CONTENT_TYPE" do
        headers = { "CONTENT_TYPE" => "application/json" }
        body = '{"key": "value"}'

        result = helper.parse_payload(body, headers)

        expect(result).to eq({ "key" => "value" })
      end

      it "handles lowercase content-type" do
        headers = { "content-type" => "application/json" }
        body = '{"key": "value"}'

        result = helper.parse_payload(body, headers)

        expect(result).to eq({ "key" => "value" })
      end

      it "handles HTTP_CONTENT_TYPE" do
        headers = { "HTTP_CONTENT_TYPE" => "application/json" }
        body = '{"key": "value"}'

        result = helper.parse_payload(body, headers)

        expect(result).to eq({ "key" => "value" })
      end
    end

    context "with invalid JSON" do
      it "returns raw body when JSON parsing fails" do
        headers = { "Content-Type" => "application/json" }
        body = '{"invalid": json}'

        result = helper.parse_payload(body, headers)

        expect(result).to eq(body)
      end
    end

    context "with JSON security limits" do
      it "handles deeply nested JSON within limits" do
        headers = { "Content-Type" => "application/json" }
        # Create a nested JSON structure within reasonable limits
        nested_json = '{"level1": {"level2": {"level3": {"value": "test"}}}}'

        result = helper.parse_payload(nested_json, headers)

        expect(result).to eq({ "level1" => { "level2" => { "level3" => { "value" => "test" } } } })
      end

      it "returns raw body when JSON exceeds size limits" do
        headers = { "Content-Type" => "application/json" }

        # Mock the safe_json_parse method to test the size limit behavior
        allow(helper).to receive(:safe_json_parse).and_raise(ArgumentError, "JSON payload too large for parsing")

        # Create a JSON string
        json_data = '{"data": "test"}'

        result = helper.parse_payload(json_data, headers)

        # Should return raw body when size limit exceeded
        expect(result).to eq(json_data)
      end

      it "logs debug message when JSON security limits are exceeded" do
        headers = { "Content-Type" => "application/json" }

        # Mock logger to capture debug messages
        logger = instance_double("Logger")
        allow(helper).to receive(:log).and_return(logger)
        expect(logger).to receive(:warn).with(/JSON parsing limit exceeded/)

        # Mock the safe_json_parse method to simulate nesting limit exceeded
        allow(helper).to receive(:safe_json_parse).and_raise(ArgumentError, "nesting exceeded")

        json_data = '{"data": "test"}'
        result = helper.parse_payload(json_data, headers)
        expect(result).to eq(json_data)
      end
    end

    context "with non-JSON content" do
      it "returns raw body for plain text" do
        headers = { "Content-Type" => "text/plain" }
        body = "plain text content"

        result = helper.parse_payload(body, headers)

        expect(result).to eq(body)
      end

      it "returns raw body for XML" do
        headers = { "Content-Type" => "application/xml" }
        body = "<xml>content</xml>"

        result = helper.parse_payload(body, headers)

        expect(result).to eq(body)
      end
    end
  end

  describe "#load_handler" do
    before do
      # Clear plugin registries before each test
      Hooks::Core::PluginLoader.clear_plugins
    end

    after do
      # Clear plugin registries after each test
      Hooks::Core::PluginLoader.clear_plugins
    end

    context "when handler is not loaded at boot time" do
      it "returns error indicating handler not found" do
        expect do
          helper.load_handler("NonexistentHandler")
        end.to raise_error(StandardError, /Handler plugin.*not found/)
      end
    end

    context "when built-in handler is loaded at boot time" do
      before do
        # Load built-in plugins (includes DefaultHandler)
        Hooks::Core::PluginLoader.load_all_plugins({})
      end

      it "successfully loads DefaultHandler" do
        handler = helper.load_handler("default_handler")
        expect(handler).to be_an_instance_of(DefaultHandler)
      end
    end
  end

  describe "#safe_json_parse" do
    it "raises ArgumentError when JSON payload exceeds size limit" do
      # Test the actual size limit by temporarily setting a small limit
      stub_const("ENV", ENV.to_h.merge("JSON_MAX_SIZE" => "10"))

      large_json = '{"data": "' + "x" * 20 + '"}'

      expect {
        helper.send(:safe_json_parse, large_json)
      }.to raise_error(ArgumentError, "JSON payload too large for parsing")
    end

    it "raises ArgumentError when JSON_MAX_NESTING is invalid (too low)" do
      stub_const("ENV", ENV.to_h.merge("JSON_MAX_NESTING" => "0"))

      expect {
        helper.send(:safe_json_parse, '{"test": "data"}')
      }.to raise_error(ArgumentError, "Invalid JSON_MAX_NESTING value: must be between 1 and 100")
    end

    it "raises ArgumentError when JSON_MAX_NESTING is invalid (too high)" do
      stub_const("ENV", ENV.to_h.merge("JSON_MAX_NESTING" => "101"))

      expect {
        helper.send(:safe_json_parse, '{"test": "data"}')
      }.to raise_error(ArgumentError, "Invalid JSON_MAX_NESTING value: must be between 1 and 100")
    end

    it "raises ArgumentError when JSON_MAX_SIZE is invalid (too low)" do
      stub_const("ENV", ENV.to_h.merge("JSON_MAX_SIZE" => "0"))

      expect {
        helper.send(:safe_json_parse, '{"test": "data"}')
      }.to raise_error(ArgumentError, "Invalid JSON_MAX_SIZE value: must be between 1 and 104857600 bytes")
    end

    it "raises ArgumentError when JSON_MAX_SIZE is invalid (too high)" do
      stub_const("ENV", ENV.to_h.merge("JSON_MAX_SIZE" => "104857601"))

      expect {
        helper.send(:safe_json_parse, '{"test": "data"}')
      }.to raise_error(ArgumentError, "Invalid JSON_MAX_SIZE value: must be between 1 and 104857600 bytes")
    end

    it "parses valid JSON with valid limits" do
      stub_const("ENV", ENV.to_h.merge("JSON_MAX_NESTING" => "5", "JSON_MAX_SIZE" => "100"))

      result = helper.send(:safe_json_parse, '{"test": "data"}')
      expect(result).to eq({ "test" => "data" })
    end
  end

  describe "#determine_error_code" do
    it "returns 400 for ArgumentError" do
      error = ArgumentError.new("bad argument")

      expect(helper.send(:determine_error_code, error)).to eq(400)
    end

    it "returns 501 for NotImplementedError" do
      error = NotImplementedError.new("not implemented")

      expect(helper.send(:determine_error_code, error)).to eq(501)
    end

    it "returns 500 for any other error" do
      error = StandardError.new("generic error")

      expect(helper.send(:determine_error_code, error)).to eq(500)
    end
  end

  describe "#ip_filtering!" do
    let(:headers) { { "X-Forwarded-For" => "192.168.1.1" } }
    let(:endpoint_config) { {} }
    let(:global_config) { {} }
    let(:request_context) { { request_id: "test-request-id" } }
    let(:env) { {} }

    it "delegates to Network::IpFiltering.ip_filtering!" do
      expect(Hooks::Core::Network::IpFiltering).to receive(:ip_filtering!).with(
        headers,
        endpoint_config,
        global_config,
        request_context,
        env
      )

      helper.ip_filtering!(headers, endpoint_config, global_config, request_context, env)
    end
  end
end
