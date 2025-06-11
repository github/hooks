# frozen_string_literal: true

require "tempfile"

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

  describe "#valid_handler_class_name?" do
    it "returns true for valid handler class names" do
      valid_names = ["MyHandler", "GitHubHandler", "Team1Handler", "APIHandler"]
      
      valid_names.each do |name|
        expect(helper.send(:valid_handler_class_name?, name)).to be true
      end
    end

    it "returns false for non-string input" do
      expect(helper.send(:valid_handler_class_name?, nil)).to be false
      expect(helper.send(:valid_handler_class_name?, 123)).to be false
      expect(helper.send(:valid_handler_class_name?, [])).to be false
    end

    it "returns false for empty or whitespace-only strings" do
      expect(helper.send(:valid_handler_class_name?, "")).to be false
      expect(helper.send(:valid_handler_class_name?, "   ")).to be false
      expect(helper.send(:valid_handler_class_name?, "\t")).to be false
    end

    it "returns false for class names not starting with uppercase" do
      expect(helper.send(:valid_handler_class_name?, "myHandler")).to be false
      expect(helper.send(:valid_handler_class_name?, "handler")).to be false
      expect(helper.send(:valid_handler_class_name?, "123Handler")).to be false
    end

    it "returns false for class names with invalid characters" do
      expect(helper.send(:valid_handler_class_name?, "My-Handler")).to be false
      expect(helper.send(:valid_handler_class_name?, "My.Handler")).to be false
      expect(helper.send(:valid_handler_class_name?, "My Handler")).to be false
      expect(helper.send(:valid_handler_class_name?, "My/Handler")).to be false
    end

    it "returns false for dangerous class names" do
      Hooks::Security::DANGEROUS_CLASSES.each do |dangerous_class|
        expect(helper.send(:valid_handler_class_name?, dangerous_class)).to be false
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

    it "returns 500 for other errors" do
      error = StandardError.new("generic error")
      
      expect(helper.send(:determine_error_code, error)).to eq(500)
    end

    it "returns 500 for RuntimeError" do
      error = RuntimeError.new("runtime error")
      
      expect(helper.send(:determine_error_code, error)).to eq(500)
    end
  end

  describe "#load_handler" do
    let(:temp_dir) { Dir.mktmpdir }
    let(:handler_class_name) { "TestHandler" }
    
    after do
      FileUtils.rm_rf(temp_dir)
    end

    context "with valid handler" do
      it "loads and instantiates a valid handler" do
        # Create a test handler file
        handler_content = <<~RUBY
          class TestHandler < Hooks::Handlers::Base
            def call(payload:, headers:, config:)
              { status: "ok" }
            end
          end
        RUBY
        
        File.write(File.join(temp_dir, "test_handler.rb"), handler_content)
        
        result = helper.load_handler(handler_class_name, temp_dir)
        
        expect(result).to be_an_instance_of(TestHandler)
        expect(result).to respond_to(:call)
      end
    end

    context "with invalid handler class name" do
      it "raises error for invalid class name" do
        expect { helper.load_handler("invalid-name", temp_dir) }.to raise_error(StandardError, /400.*invalid handler class name/)
      end

      it "raises error for dangerous class name" do
        expect { helper.load_handler("File", temp_dir) }.to raise_error(StandardError, /400.*invalid handler class name/)
      end
    end

    context "with path traversal attempts" do
      it "raises error for path traversal" do
        expect { helper.load_handler("../../../EvilHandler", temp_dir) }.to raise_error(StandardError, /400.*invalid handler class name/)
      end
    end

    context "with missing handler file" do
      it "raises LoadError when handler file does not exist" do
        expect { helper.load_handler("MissingHandler", temp_dir) }.to raise_error(LoadError, /Handler MissingHandler not found/)
      end
    end

    context "with handler that doesn't inherit from Base" do
      it "raises error when handler doesn't inherit from Base" do
        # Create a handler that doesn't inherit from Base
        handler_content = <<~RUBY
          class BadHandler
            def call(payload:, headers:, config:)
              { status: "ok" }
            end
          end
        RUBY
        
        File.write(File.join(temp_dir, "bad_handler.rb"), handler_content)
        
        expect { helper.load_handler("BadHandler", temp_dir) }.to raise_error(StandardError, /400.*must inherit from Hooks::Handlers::Base/)
      end
    end

    context "with handler file that has syntax errors" do
      it "raises SyntaxError when handler file has syntax errors" do
        # Create a handler with syntax errors
        handler_content = "class SyntaxErrorHandler < Hooks::Handlers::Base\n  def call\n    {invalid syntax\n  end\nend"
        
        File.write(File.join(temp_dir, "syntax_error_handler.rb"), handler_content)
        
        expect { helper.load_handler("SyntaxErrorHandler", temp_dir) }.to raise_error(SyntaxError)
      end
    end
  end
end