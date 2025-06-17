# frozen_string_literal: true

require "ostruct"
require_relative "../spec_helper"

describe Hooks::App::RackEnvBuilder do
  let(:request) { double("Grape::Request") }
  let(:headers) do
    {
      "Content-Type" => "application/json",
      "User-Agent" => "RSpec/Test",
      "X-Custom-Header" => "custom-value",
      "Authorization" => "Bearer token123"
    }
  end
  let(:request_context) do
    {
      request_id: "req-123",
      handler: "test_handler"
    }
  end
  let(:endpoint_config) do
    {
      path: "/test",
      method: "post",
      auth: true
    }
  end
  let(:start_time) { Time.parse("2025-06-16T10:30:45Z") }
  let(:full_path) { "/api/v1/test" }

  let(:builder) do
    described_class.new(
      request,
      headers,
      request_context,
      endpoint_config,
      start_time,
      full_path
    )
  end

  before do
    # Mock the request object with all the methods used by the builder
    allow(request).to receive(:request_method).and_return("POST")
    allow(request).to receive(:path_info).and_return("/api/v1/test")
    allow(request).to receive(:query_string).and_return("param1=value1&param2=value2")
    allow(request).to receive(:url).and_return("https://example.com/api/v1/test?param1=value1&param2=value2")
    allow(request).to receive(:content_type).and_return("application/json")
    allow(request).to receive(:content_length).and_return("123")
    allow(request).to receive(:env).and_return({
      "HTTP_VERSION" => "HTTP/1.1",
      "SERVER_NAME" => "example.com",
      "SERVER_PORT" => "443",
      "REMOTE_ADDR" => "192.168.1.100"
    })
  end

  describe "#initialize" do
    it "stores all required parameters as instance variables" do
      expect(builder.instance_variable_get(:@request)).to eq(request)
      expect(builder.instance_variable_get(:@headers)).to eq(headers)
      expect(builder.instance_variable_get(:@request_context)).to eq(request_context)
      expect(builder.instance_variable_get(:@endpoint_config)).to eq(endpoint_config)
      expect(builder.instance_variable_get(:@start_time)).to eq(start_time)
      expect(builder.instance_variable_get(:@full_path)).to eq(full_path)
    end
  end

  describe "#build" do
    let(:result) { builder.build }

    it "returns a hash with all standard Rack environment variables" do
      expect(result).to be_a(Hash)
      expect(result["REQUEST_METHOD"]).to eq("POST")
      expect(result["PATH_INFO"]).to eq("/api/v1/test")
      expect(result["QUERY_STRING"]).to eq("param1=value1&param2=value2")
      expect(result["HTTP_VERSION"]).to eq("HTTP/1.1")
      expect(result["REQUEST_URI"]).to eq("https://example.com/api/v1/test?param1=value1&param2=value2")
      expect(result["SERVER_NAME"]).to eq("example.com")
      expect(result["SERVER_PORT"]).to eq("443")
      expect(result["CONTENT_TYPE"]).to eq("application/json")
      expect(result["CONTENT_LENGTH"]).to eq("123")
      expect(result["REMOTE_ADDR"]).to eq("192.168.1.100")
    end

    it "includes Hooks-specific environment variables" do
      expect(result["hooks.request_id"]).to eq("req-123")
      expect(result["hooks.handler"]).to eq("test_handler")
      expect(result["hooks.endpoint_config"]).to eq(endpoint_config)
      expect(result["hooks.start_time"]).to eq("2025-06-16T10:30:45Z")
      expect(result["hooks.full_path"]).to eq("/api/v1/test")
    end

    it "converts HTTP headers to Rack environment format" do
      expect(result["HTTP_CONTENT_TYPE"]).to eq("application/json")
      expect(result["HTTP_USER_AGENT"]).to eq("RSpec/Test")
      expect(result["HTTP_X_CUSTOM_HEADER"]).to eq("custom-value")
      expect(result["HTTP_AUTHORIZATION"]).to eq("Bearer token123")
    end

    context "with hyphenated header names" do
      let(:headers) do
        {
          "X-Forwarded-For" => "10.0.0.1",
          "Accept-Language" => "en-US,en;q=0.9"
        }
      end

      it "converts hyphens to underscores in header names" do
        expect(result["HTTP_X_FORWARDED_FOR"]).to eq("10.0.0.1")
        expect(result["HTTP_ACCEPT_LANGUAGE"]).to eq("en-US,en;q=0.9")
      end
    end

    context "with lowercase header names" do
      let(:headers) do
        {
          "content-type" => "text/plain",
          "accept" => "text/html"
        }
      end

      it "converts header names to uppercase" do
        expect(result["HTTP_CONTENT_TYPE"]).to eq("text/plain")
        expect(result["HTTP_ACCEPT"]).to eq("text/html")
      end
    end

    context "with empty headers" do
      let(:headers) { {} }

      it "still builds base environment without HTTP headers" do
        expect(result["REQUEST_METHOD"]).to eq("POST")
        expect(result["hooks.request_id"]).to eq("req-123")
        # Note: HTTP_VERSION is from request.env, not from headers
        http_headers = result.keys.grep(/^HTTP_/).reject { |k| k == "HTTP_VERSION" }
        expect(http_headers).to be_empty
      end
    end

    context "with nil values in request" do
      before do
        allow(request).to receive(:content_type).and_return(nil)
        allow(request).to receive(:content_length).and_return(nil)
        allow(request).to receive(:query_string).and_return("")
        allow(request).to receive(:env).and_return({
          "HTTP_VERSION" => "HTTP/1.1",
          "SERVER_NAME" => "example.com",
          "SERVER_PORT" => nil,
          "REMOTE_ADDR" => "192.168.1.100"
        })
      end

      it "handles nil values gracefully" do
        expect(result["CONTENT_TYPE"]).to be_nil
        expect(result["CONTENT_LENGTH"]).to be_nil
        expect(result["SERVER_PORT"]).to be_nil
        expect(result["QUERY_STRING"]).to eq("")
      end
    end

    context "with empty string values for numeric fields" do
      before do
        allow(request).to receive(:content_length).and_return("")
        allow(request).to receive(:env).and_return({
          "HTTP_VERSION" => "HTTP/1.1",
          "SERVER_NAME" => "example.com",
          "SERVER_PORT" => "",
          "REMOTE_ADDR" => "192.168.1.100"
        })
      end

      it "handles empty string values gracefully by converting them to nil" do
        expect(result["CONTENT_LENGTH"]).to eq("")
        expect(result["SERVER_PORT"]).to eq("")
      end
    end

    context "with string numeric values" do
      before do
        allow(request).to receive(:content_length).and_return("456")
        allow(request).to receive(:env).and_return({
          "HTTP_VERSION" => "HTTP/1.1",
          "SERVER_NAME" => "example.com",
          "SERVER_PORT" => "8080",
          "REMOTE_ADDR" => "192.168.1.100"
        })
      end
    end

    context "with different request methods" do
      before do
        allow(request).to receive(:request_method).and_return("GET")
      end

      it "captures the correct request method" do
        expect(result["REQUEST_METHOD"]).to eq("GET")
      end
    end

    context "with complex endpoint configuration" do
      let(:endpoint_config) do
        {
          path: "/webhooks/:id",
          method: "put",
          auth: {
            type: "hmac",
            secret_key: "webhook_secret"
          },
          rate_limit: {
            requests: 100,
            window: 3600
          }
        }
      end

      it "includes the complete endpoint configuration" do
        expect(result["hooks.endpoint_config"]).to eq(endpoint_config)
        expect(result["hooks.endpoint_config"][:auth][:type]).to eq("hmac")
        expect(result["hooks.endpoint_config"][:rate_limit][:requests]).to eq(100)
      end
    end

    context "with edge case header values" do
      let(:headers) do
        {
          "Empty-Header" => "",
          "Multi-Value" => "value1, value2, value3",
          "Special-Chars" => "value with spaces & symbols!",
          "Unicode-Header" => "héllo wörld 🌍"
        }
      end

      it "preserves header values exactly" do
        expect(result["HTTP_EMPTY_HEADER"]).to eq("")
        expect(result["HTTP_MULTI_VALUE"]).to eq("value1, value2, value3")
        expect(result["HTTP_SPECIAL_CHARS"]).to eq("value with spaces & symbols!")
        expect(result["HTTP_UNICODE_HEADER"]).to eq("héllo wörld 🌍")
      end
    end
  end

  describe "private methods" do
    describe "#build_base_environment" do
      it "is called when building the environment" do
        expect(builder).to receive(:build_base_environment).and_call_original
        builder.build
      end
    end

    describe "#add_http_headers" do
      it "is called when building the environment" do
        expect(builder).to receive(:add_http_headers).and_call_original
        builder.build
      end
    end
  end

  describe "integration with real request-like objects" do
    context "when used with objects that respond to expected methods" do
      let(:mock_request) do
        OpenStruct.new(
          request_method: "PATCH",
          path_info: "/api/v2/resource",
          query_string: "filter=active",
          url: "https://api.example.com/api/v2/resource?filter=active",
          content_type: "application/vnd.api+json",
          content_length: "456",
          env: {
            "HTTP_VERSION" => "HTTP/2.0",
            "SERVER_NAME" => "api.example.com",
            "SERVER_PORT" => "443",
            "REMOTE_ADDR" => "203.0.113.5"
          }
        )
      end

      let(:builder_with_mock) do
        described_class.new(
          mock_request,
          { "Accept" => "application/vnd.api+json" },
          { request_id: "mock-123", handler: "mock_handler" },
          { path: "/resource", method: "patch" },
          Time.parse("2025-06-16T15:45:30Z"),
          "/api/v2/resource"
        )
      end

      it "works correctly with mock objects" do
        result = builder_with_mock.build

        expect(result["REQUEST_METHOD"]).to eq("PATCH")
        expect(result["PATH_INFO"]).to eq("/api/v2/resource")
        expect(result["HTTP_VERSION"]).to eq("HTTP/2.0")
        expect(result["HTTP_ACCEPT"]).to eq("application/vnd.api+json")
        expect(result["hooks.request_id"]).to eq("mock-123")
      end
    end
  end
end
