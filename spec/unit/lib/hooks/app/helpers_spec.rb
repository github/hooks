# frozen_string_literal: true

require "tempfile"
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
        raise StandardError, "#{code}: #{message}"
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

        expect { helper.enforce_request_limits(config) }.to raise_error(StandardError, /413.*too large/)
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

        expect(result).to eq({ key: "value" })
      end

      it "parses JSON that looks like JSON without content type" do
        headers = {}
        body = '{"key": "value"}'

        result = helper.parse_payload(body, headers)

        expect(result).to eq({ key: "value" })
      end

      it "parses JSON arrays" do
        headers = {}
        body = '[{"key": "value"}]'

        result = helper.parse_payload(body, headers)

        expect(result).to eq([{ "key" => "value" }])
      end

      it "symbolizes keys by default" do
        headers = { "Content-Type" => "application/json" }
        body = '{"string_key": "value", "nested": {"inner_key": "inner_value"}}'

        result = helper.parse_payload(body, headers)

        expect(result).to eq({
          string_key: "value",
          nested: { "inner_key" => "inner_value" } # Only top level is symbolized
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

        expect(result).to eq({ key: "value" })
      end

      it "handles lowercase content-type" do
        headers = { "content-type" => "application/json" }
        body = '{"key": "value"}'

        result = helper.parse_payload(body, headers)

        expect(result).to eq({ key: "value" })
      end

      it "handles HTTP_CONTENT_TYPE" do
        headers = { "HTTP_CONTENT_TYPE" => "application/json" }
        body = '{"key": "value"}'

        result = helper.parse_payload(body, headers)

        expect(result).to eq({ key: "value" })
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
        end.to raise_error(StandardError, /failed to get handler.*not found/)
      end
    end

    context "when built-in handler is loaded at boot time" do
      before do
        # Load built-in plugins (includes DefaultHandler)
        Hooks::Core::PluginLoader.load_all_plugins({})
      end

      it "successfully loads DefaultHandler" do
        handler = helper.load_handler("DefaultHandler")
        expect(handler).to be_an_instance_of(DefaultHandler)
      end
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
end
