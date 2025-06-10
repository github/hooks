# frozen_string_literal: true

describe Hooks::Core::LoggerFactory do
  describe ".create" do
    context "with default parameters" do
      it "creates a logger with INFO level and JSON formatter" do
        logger = described_class.create

        expect(logger).to be_a(Logger)
        expect(logger.level).to eq(Logger::INFO)
      end

      it "logs to STDOUT by default" do
        logger = described_class.create

        # The internal instance variable should be set to STDOUT
        expect(logger.instance_variable_get(:@logdev).dev).to eq($stdout)
      end
    end

    context "with custom log level" do
      it "creates logger with DEBUG level" do
        logger = described_class.create(log_level: "debug")

        expect(logger.level).to eq(Logger::DEBUG)
      end

      it "creates logger with WARN level" do
        logger = described_class.create(log_level: "warn")

        expect(logger.level).to eq(Logger::WARN)
      end

      it "creates logger with ERROR level" do
        logger = described_class.create(log_level: "error")

        expect(logger.level).to eq(Logger::ERROR)
      end

      it "creates logger with INFO level for invalid level" do
        logger = described_class.create(log_level: "invalid")

        expect(logger.level).to eq(Logger::INFO)
      end

      it "handles nil log level gracefully" do
        logger = described_class.create(log_level: nil)

        expect(logger.level).to eq(Logger::INFO)
      end

      it "handles case insensitive log levels" do
        logger = described_class.create(log_level: "DEBUG")

        expect(logger.level).to eq(Logger::DEBUG)
      end
    end

    context "with custom logger" do
      it "returns the custom logger instance" do
        custom_logger = Logger.new(StringIO.new)
        custom_logger.level = Logger::WARN

        result = described_class.create(custom_logger: custom_logger)

        expect(result).to be(custom_logger)
        expect(result.level).to eq(Logger::WARN)
      end

      it "ignores log_level parameter when custom_logger is provided" do
        custom_logger = Logger.new(StringIO.new)
        custom_logger.level = Logger::ERROR

        result = described_class.create(log_level: "debug", custom_logger: custom_logger)

        expect(result).to be(custom_logger)
        expect(result.level).to eq(Logger::ERROR) # Should remain unchanged
      end
    end

    context "JSON formatting" do
      let(:output) { StringIO.new }
      let(:logger) do
        logger = described_class.create(log_level: "debug")
        logger.instance_variable_set(:@logdev, Logger::LogDevice.new(output))
        logger
      end

      it "formats log messages as JSON" do
        logger.info("Test message")

        output.rewind
        log_line = output.read
        parsed = JSON.parse(log_line)

        expect(parsed).to include(
          "level" => "info",
          "message" => "Test message"
        )
        expect(parsed["timestamp"]).to match(/\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(\.\d+)?Z/)
      end

      it "includes request context when available" do
        Thread.current[:hooks_request_context] = {
          "request_id" => "test-123",
          "endpoint" => "/webhook/test"
        }

        logger.warn("Context test")

        output.rewind
        log_line = output.read
        parsed = JSON.parse(log_line)

        expect(parsed).to include(
          "level" => "warn",
          "message" => "Context test",
          "request_id" => "test-123",
          "endpoint" => "/webhook/test"
        )
      ensure
        Thread.current[:hooks_request_context] = nil
      end

      it "works without request context" do
        Thread.current[:hooks_request_context] = nil

        logger.error("No context test")

        output.rewind
        log_line = output.read
        parsed = JSON.parse(log_line)

        expect(parsed).to include(
          "level" => "error",
          "message" => "No context test"
        )
        expect(parsed).not_to have_key("request_id")
      end

      it "handles different severity levels correctly" do
        ["debug", "info", "warn", "error"].each do |level|
          output.truncate(0)
          output.rewind

          logger.send(level, "#{level} message")

          output.rewind
          log_line = output.read
          parsed = JSON.parse(log_line)

          expect(parsed["level"]).to eq(level)
          expect(parsed["message"]).to eq("#{level} message")
        end
      end
    end
  end

  describe ".parse_log_level" do
    it "converts string log levels to Logger constants" do
      expect(described_class.send(:parse_log_level, "debug")).to eq(Logger::DEBUG)
      expect(described_class.send(:parse_log_level, "info")).to eq(Logger::INFO)
      expect(described_class.send(:parse_log_level, "warn")).to eq(Logger::WARN)
      expect(described_class.send(:parse_log_level, "error")).to eq(Logger::ERROR)
    end

    it "handles case insensitive input" do
      expect(described_class.send(:parse_log_level, "DEBUG")).to eq(Logger::DEBUG)
      expect(described_class.send(:parse_log_level, "Info")).to eq(Logger::INFO)
      expect(described_class.send(:parse_log_level, "WARN")).to eq(Logger::WARN)
      expect(described_class.send(:parse_log_level, "Error")).to eq(Logger::ERROR)
    end

    it "defaults to INFO for invalid levels" do
      expect(described_class.send(:parse_log_level, "invalid")).to eq(Logger::INFO)
      expect(described_class.send(:parse_log_level, "")).to eq(Logger::INFO)
      expect(described_class.send(:parse_log_level, nil)).to eq(Logger::INFO)
    end
  end

  describe ".json_formatter" do
    let(:formatter) { described_class.send(:json_formatter) }
    let(:test_time) { Time.parse("2023-01-01T12:00:00Z") }

    it "returns a proc" do
      expect(formatter).to be_a(Proc)
    end

    it "formats log entry as JSON with newline" do
      result = formatter.call("INFO", test_time, nil, "Test message")
      parsed = JSON.parse(result.chomp)

      expect(parsed).to eq({
        "timestamp" => "2023-01-01T12:00:00Z",
        "level" => "info",
        "message" => "Test message"
      })
      expect(result).to end_with("\n")
    end

    it "includes thread context when available" do
      Thread.current[:hooks_request_context] = { "user_id" => 123 }

      result = formatter.call("WARN", test_time, nil, "Warning message")
      parsed = JSON.parse(result.chomp)

      expect(parsed).to eq({
        "timestamp" => "2023-01-01T12:00:00Z",
        "level" => "warn",
        "message" => "Warning message",
        "user_id" => 123
      })
    ensure
      Thread.current[:hooks_request_context] = nil
    end

    it "handles complex message objects" do
      complex_message = { error: "Something failed", details: { code: 500 } }

      result = formatter.call("ERROR", test_time, nil, complex_message)
      parsed = JSON.parse(result.chomp)

      # JSON parsing converts symbol keys to strings
      expect(parsed["message"]).to eq({
        "error" => "Something failed",
        "details" => { "code" => 500 }
      })
    end
  end
end

describe Hooks::Core::LogContext do
  after do
    Thread.current[:hooks_request_context] = nil
  end

  describe ".set" do
    it "sets request context in thread local storage" do
      context = { "request_id" => "test-123", "user" => "testuser" }

      described_class.set(context)

      expect(Thread.current[:hooks_request_context]).to eq(context)
    end

    it "overwrites existing context" do
      Thread.current[:hooks_request_context] = { "old" => "data" }

      new_context = { "new" => "data" }
      described_class.set(new_context)

      expect(Thread.current[:hooks_request_context]).to eq(new_context)
    end
  end

  describe ".clear" do
    it "clears request context" do
      Thread.current[:hooks_request_context] = { "test" => "data" }

      described_class.clear

      expect(Thread.current[:hooks_request_context]).to be_nil
    end

    it "works when context is already nil" do
      Thread.current[:hooks_request_context] = nil

      expect { described_class.clear }.not_to raise_error
      expect(Thread.current[:hooks_request_context]).to be_nil
    end
  end

  describe ".with" do
    it "sets context for block execution then restores original" do
      original_context = { "original" => "value" }
      Thread.current[:hooks_request_context] = original_context

      block_context = { "block" => "value" }
      context_during_block = nil

      described_class.with(block_context) do
        context_during_block = Thread.current[:hooks_request_context]
      end

      expect(context_during_block).to eq(block_context)
      expect(Thread.current[:hooks_request_context]).to eq(original_context)
    end

    it "restores context even if block raises exception" do
      original_context = { "original" => "value" }
      Thread.current[:hooks_request_context] = original_context

      block_context = { "block" => "value" }

      expect {
        described_class.with(block_context) do
          raise StandardError, "Test error"
        end
      }.to raise_error(StandardError, "Test error")

      expect(Thread.current[:hooks_request_context]).to eq(original_context)
    end

    it "works when original context is nil" do
      Thread.current[:hooks_request_context] = nil

      block_context = { "block" => "value" }
      context_during_block = nil

      described_class.with(block_context) do
        context_during_block = Thread.current[:hooks_request_context]
      end

      expect(context_during_block).to eq(block_context)
      expect(Thread.current[:hooks_request_context]).to be_nil
    end

    it "yields to the block" do
      yielded_value = nil

      described_class.with({}) do |arg|
        yielded_value = arg
      end

      expect(yielded_value).to be_nil # with doesn't pass arguments
    end
  end
end
