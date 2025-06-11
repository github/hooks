# frozen_string_literal: true

describe Hooks::App::Helpers do
  # Create a test class that includes the helpers module
  let(:test_class) do
    Class.new do
      include Hooks::App::Helpers

      # Mock methods that Grape provides
      attr_accessor :headers, :env, :request

      def initialize
        @headers = {}
        @env = {}
        @request = nil
      end

      def respond_to?(method_name)
        method_name == :request
      end

      def error!(message, code)
        raise StandardError, "#{message} (#{code})"
      end
    end
  end

  let(:helper_instance) { test_class.new }

  describe "#uuid" do
    it "generates a UUID string" do
      uuid = helper_instance.uuid
      expect(uuid).to be_a(String)
      expect(uuid).to match(/\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/i)
    end

    it "generates unique UUIDs" do
      uuid1 = helper_instance.uuid
      uuid2 = helper_instance.uuid
      expect(uuid1).not_to eq(uuid2)
    end
  end

  describe "#enforce_request_limits" do
    let(:config) { { request_limit: 1000 } }

    context "when content length is within limits" do
      it "does not raise error for header content length" do
        helper_instance.headers["Content-Length"] = "500"
        expect { helper_instance.enforce_request_limits(config) }.not_to raise_error
      end

      it "does not raise error for env content length" do
        helper_instance.env["CONTENT_LENGTH"] = "500"
        expect { helper_instance.enforce_request_limits(config) }.not_to raise_error
      end

      it "does not raise error when no content length is provided" do
        expect { helper_instance.enforce_request_limits(config) }.not_to raise_error
      end
    end

    context "when content length exceeds limits" do
      it "raises error for header content length" do
        helper_instance.headers["Content-Length"] = "2000"
        expect { helper_instance.enforce_request_limits(config) }
          .to raise_error(StandardError, "request body too large (413)")
      end

      it "raises error for env content length" do
        helper_instance.env["CONTENT_LENGTH"] = "2000"
        expect { helper_instance.enforce_request_limits(config) }
          .to raise_error(StandardError, "request body too large (413)")
      end

      it "handles different header name variations" do
        helper_instance.headers["CONTENT_LENGTH"] = "2000"
        expect { helper_instance.enforce_request_limits(config) }
          .to raise_error(StandardError, "request body too large (413)")

        helper_instance.headers.clear
        helper_instance.headers["content-length"] = "2000"
        expect { helper_instance.enforce_request_limits(config) }
          .to raise_error(StandardError, "request body too large (413)")

        helper_instance.headers.clear
        helper_instance.headers["HTTP_CONTENT_LENGTH"] = "2000"
        expect { helper_instance.enforce_request_limits(config) }
          .to raise_error(StandardError, "request body too large (413)")
      end
    end
  end

  describe "#parse_payload" do
    context "with JSON content type" do
      let(:headers) { { "Content-Type" => "application/json" } }

      it "parses valid JSON with symbolized keys by default" do
        raw_body = '{"key": "value", "nested": {"inner": "data"}}'
        result = helper_instance.parse_payload(raw_body, headers)
        expect(result).to eq({ key: "value", nested: { "inner" => "data" } })
      end

      it "parses valid JSON without symbolizing keys when requested" do
        raw_body = '{"key": "value", "nested": {"inner": "data"}}'
        result = helper_instance.parse_payload(raw_body, headers, symbolize: false)
        expect(result).to eq({ "key" => "value", "nested" => { "inner" => "data" } })
      end

      it "returns raw body when JSON parsing fails" do
        raw_body = "invalid json"
        result = helper_instance.parse_payload(raw_body, headers)
        expect(result).to eq("invalid json")
      end

      it "handles JSON arrays" do
        raw_body = '[{"key": "value"}]'
        result = helper_instance.parse_payload(raw_body, headers)
        expect(result).to eq([{ "key" => "value" }])
      end
    end

    context "with different content type header variations" do
      it "handles CONTENT_TYPE header" do
        headers = { "CONTENT_TYPE" => "application/json" }
        raw_body = '{"key": "value"}'
        result = helper_instance.parse_payload(raw_body, headers)
        expect(result).to eq({ key: "value" })
      end

      it "handles content-type header" do
        headers = { "content-type" => "application/json" }
        raw_body = '{"key": "value"}'
        result = helper_instance.parse_payload(raw_body, headers)
        expect(result).to eq({ key: "value" })
      end

      it "handles HTTP_CONTENT_TYPE header" do
        headers = { "HTTP_CONTENT_TYPE" => "application/json" }
        raw_body = '{"key": "value"}'
        result = helper_instance.parse_payload(raw_body, headers)
        expect(result).to eq({ key: "value" })
      end
    end

    context "without JSON content type" do
      let(:headers) { { "Content-Type" => "text/plain" } }

      it "returns raw body for non-JSON content type" do
        raw_body = "plain text data"
        result = helper_instance.parse_payload(raw_body, headers)
        expect(result).to eq("plain text data")
      end

      it "attempts to parse JSON-like strings even without JSON content type" do
        raw_body = '{"key": "value"}'
        result = helper_instance.parse_payload(raw_body, headers)
        expect(result).to eq({ key: "value" })
      end

      it "attempts to parse array-like strings" do
        raw_body = '[{"key": "value"}]'
        result = helper_instance.parse_payload(raw_body, headers)
        expect(result).to eq([{ "key" => "value" }])
      end

      it "returns raw body for non-JSON-like strings" do
        raw_body = "not json at all"
        result = helper_instance.parse_payload(raw_body, headers)
        expect(result).to eq("not json at all")
      end
    end

    context "with empty headers" do
      it "handles empty headers" do
        raw_body = '{"key": "value"}'
        result = helper_instance.parse_payload(raw_body, {})
        expect(result).to eq({ key: "value" })
      end
    end
  end

  describe "#load_handler" do
    let(:temp_dir) { "/tmp/test_handlers" }

    before do
      FileUtils.mkdir_p(temp_dir)
    end

    after do
      FileUtils.rm_rf(temp_dir)
    end

    context "when handler file exists" do
      it "loads simple handler class" do
        File.write("#{temp_dir}/test_handler.rb", <<~RUBY)
          class TestHandler
            def initialize
            end
          end
        RUBY

        expect(helper_instance.load_handler("TestHandler", temp_dir)).to be_a(Object)
        expect(Object.const_defined?("TestHandler")).to be true
        Object.send(:remove_const, "TestHandler") if Object.const_defined?("TestHandler")
      end

      it "converts camelCase to snake_case filename" do
        File.write("#{temp_dir}/github_handler.rb", <<~RUBY)
          class GithubHandler
            def initialize
            end
          end
        RUBY

        expect(helper_instance.load_handler("GithubHandler", temp_dir)).to be_a(Object)
        Object.send(:remove_const, "GithubHandler") if Object.const_defined?("GithubHandler")
      end

      it "converts PascalCase with acronyms to snake_case filename" do
        File.write("#{temp_dir}/git_hub_handler.rb", <<~RUBY)
          class GitHubHandler
            def initialize
            end
          end
        RUBY

        expect(helper_instance.load_handler("GitHubHandler", temp_dir)).to be_a(Object)
        Object.send(:remove_const, "GitHubHandler") if Object.const_defined?("GitHubHandler")
      end
    end

    context "when handler file does not exist" do
      it "raises LoadError with proper message" do
        expect { helper_instance.load_handler("NonExistentHandler", temp_dir) }
          .to raise_error(LoadError, /Handler NonExistentHandler not found/)
      end
    end

    context "when handler class cannot be instantiated" do
      it "raises error when class has invalid syntax" do
        File.write("#{temp_dir}/broken_handler.rb", "class BrokenHandler\n  def initialize\n    raise 'initialization error'\n  end\nend")

        expect { helper_instance.load_handler("BrokenHandler", temp_dir) }
          .to raise_error(StandardError, /failed to load handler BrokenHandler/)
        Object.send(:remove_const, "BrokenHandler") if Object.const_defined?("BrokenHandler")
      end
    end
  end

  describe "#determine_error_code" do
    it "returns 400 for ArgumentError" do
      error = ArgumentError.new("test")
      expect(helper_instance.determine_error_code(error)).to eq(400)
    end

    it "returns 501 for NotImplementedError" do
      error = NotImplementedError.new("test")
      expect(helper_instance.determine_error_code(error)).to eq(501)
    end

    it "returns 500 for StandardError" do
      error = StandardError.new("test")
      expect(helper_instance.determine_error_code(error)).to eq(500)
    end

    it "returns 500 for RuntimeError" do
      error = RuntimeError.new("test")
      expect(helper_instance.determine_error_code(error)).to eq(500)
    end

    it "returns 500 for other exception types" do
      error = NoMethodError.new("test")
      expect(helper_instance.determine_error_code(error)).to eq(500)
    end
  end
end