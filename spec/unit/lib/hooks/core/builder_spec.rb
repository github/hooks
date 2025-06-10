# frozen_string_literal: true

describe Hooks::Core::Builder do
  let(:temp_dir) { "/tmp/hooks_builder_test" }

  before do
    FileUtils.mkdir_p(temp_dir)
  end

  after do
    FileUtils.rm_rf(temp_dir)
  end

  describe "#initialize" do
    it "initializes with no parameters" do
      builder = described_class.new

      expect(builder.instance_variable_get(:@log)).to be_nil
      expect(builder.instance_variable_get(:@config_input)).to be_nil
    end

    it "initializes with config parameter" do
      config = { log_level: "debug" }
      builder = described_class.new(config: config)

      expect(builder.instance_variable_get(:@config_input)).to eq(config)
    end

    it "initializes with custom logger" do
      logger = double("Logger")
      builder = described_class.new(log: logger)

      expect(builder.instance_variable_get(:@log)).to eq(logger)
    end

    it "initializes with both config and logger" do
      config = { environment: "test" }
      logger = double("Logger")
      builder = described_class.new(config: config, log: logger)

      expect(builder.instance_variable_get(:@config_input)).to eq(config)
      expect(builder.instance_variable_get(:@log)).to eq(logger)
    end
  end

  describe "#build" do
    context "with minimal configuration" do
      let(:builder) { described_class.new }

      before do
        # Mock dependencies to prevent actual file system operations
        allow(Hooks::Core::ConfigLoader).to receive(:load).and_return({
          log_level: "info",
          environment: "test",
          endpoints_dir: "/nonexistent"
        })
        allow(Hooks::Core::ConfigValidator).to receive(:validate_global_config).and_return({
          log_level: "info",
          environment: "test",
          endpoints_dir: "/nonexistent"
        })
        allow(Hooks::Core::ConfigLoader).to receive(:load_endpoints).and_return([])
        allow(Hooks::Core::ConfigValidator).to receive(:validate_endpoints).and_return([])
        allow(Hooks::App::API).to receive(:create).and_return("mock_api")
      end

      it "builds and returns an API instance" do
        result = builder.build

        expect(result).to eq("mock_api")
      end

      it "calls ConfigLoader.load with the config input" do
        expect(Hooks::Core::ConfigLoader).to receive(:load).with(config_path: nil)

        builder.build
      end

      it "validates the global configuration" do
        config = { log_level: "info", environment: "test", endpoints_dir: "/nonexistent" }
        expect(Hooks::Core::ConfigValidator).to receive(:validate_global_config).with(config)

        builder.build
      end

      it "loads endpoints from the endpoints directory" do
        expect(Hooks::Core::ConfigLoader).to receive(:load_endpoints).with("/nonexistent")
        builder.build
      end

      it "validates the loaded endpoints" do
        expect(Hooks::Core::ConfigValidator).to receive(:validate_endpoints).with([])

        builder.build
      end

      it "creates API with all required parameters" do
        expect(Hooks::App::API).to receive(:create) do |args|
          expect(args[:config]).to be_a(Hash)
          expect(args[:endpoints]).to eq([])
          expect(args[:log]).to respond_to(:info)
          expect(args[:signal_handler]).to be_a(Hooks::Core::SignalHandler)
          "mock_api"
        end

        builder.build
      end
    end

    context "with custom configuration" do
      let(:config) { { log_level: "debug", environment: "development" } }
      let(:builder) { described_class.new(config: config) }

      before do
        allow(Hooks::Core::ConfigLoader).to receive(:load).and_return(config)
        allow(Hooks::Core::ConfigValidator).to receive(:validate_global_config).and_return(config)
        allow(Hooks::Core::ConfigLoader).to receive(:load_endpoints).and_return([])
        allow(Hooks::Core::ConfigValidator).to receive(:validate_endpoints).and_return([])
        allow(Hooks::App::API).to receive(:create).and_return("mock_api")
      end

      it "passes the custom config to ConfigLoader" do
        expect(Hooks::Core::ConfigLoader).to receive(:load).with(config_path: config)

        builder.build
      end
    end

    context "with custom logger" do
      let(:custom_logger) { double("Logger", info: nil) }
      let(:builder) { described_class.new(log: custom_logger) }

      before do
        allow(Hooks::Core::ConfigLoader).to receive(:load).and_return({ log_level: "info" })
        allow(Hooks::Core::ConfigValidator).to receive(:validate_global_config).and_return({ log_level: "info" })
        allow(Hooks::Core::ConfigLoader).to receive(:load_endpoints).and_return([])
        allow(Hooks::Core::ConfigValidator).to receive(:validate_endpoints).and_return([])
        allow(Hooks::App::API).to receive(:create).and_return("mock_api")
      end

      it "uses the custom logger instead of creating one" do
        expect(Hooks::Core::LoggerFactory).not_to receive(:create)

        builder.build
      end

      it "passes the custom logger to API.create" do
        expect(Hooks::App::API).to receive(:create) do |args|
          expect(args[:log]).to eq(custom_logger)
          "mock_api"
        end

        builder.build
      end
    end

    context "with endpoints" do
      let(:endpoints) do
        [
          { path: "/webhook/test1", handler: "Handler1" },
          { path: "/webhook/test2", handler: "Handler2" }
        ]
      end
      let(:builder) { described_class.new }

      before do
        allow(Hooks::Core::ConfigLoader).to receive(:load).and_return({
          endpoints_dir: "/test/endpoints"
        })
        allow(Hooks::Core::ConfigValidator).to receive(:validate_global_config).and_return({
          endpoints_dir: "/test/endpoints"
        })
        allow(Hooks::Core::ConfigLoader).to receive(:load_endpoints).and_return(endpoints)
        allow(Hooks::Core::ConfigValidator).to receive(:validate_endpoints).and_return(endpoints)
        allow(Hooks::App::API).to receive(:create).and_return("mock_api")
      end

      it "loads endpoints from the specified directory" do
        expect(Hooks::Core::ConfigLoader).to receive(:load_endpoints).with("/test/endpoints")

        builder.build
      end

      it "validates the loaded endpoints" do
        expect(Hooks::Core::ConfigValidator).to receive(:validate_endpoints).with(endpoints)

        builder.build
      end

      it "passes validated endpoints to API.create" do
        expect(Hooks::App::API).to receive(:create) do |args|
          expect(args[:endpoints]).to eq(endpoints)
          "mock_api"
        end

        builder.build
      end
    end

    context "with logging" do
      let(:builder) { described_class.new }
      let(:mock_logger) { double("Logger", info: nil) }

      before do
        allow(Hooks::Core::ConfigLoader).to receive(:load).and_return({
          log_level: "debug",
          environment: "test"
        })
        allow(Hooks::Core::ConfigValidator).to receive(:validate_global_config).and_return({
          log_level: "debug",
          environment: "test"
        })
        allow(Hooks::Core::ConfigLoader).to receive(:load_endpoints).and_return([])
        allow(Hooks::Core::ConfigValidator).to receive(:validate_endpoints).and_return([])
        allow(Hooks::Core::LoggerFactory).to receive(:create).and_return(mock_logger)
        allow(Hooks::App::API).to receive(:create).and_return("mock_api")
      end

      it "creates a logger with the configured log level" do
        expect(Hooks::Core::LoggerFactory).to receive(:create).with(
          log_level: "debug",
          custom_logger: nil
        )

        builder.build
      end

      it "logs startup information" do
        expect(mock_logger).to receive(:info).with("starting hooks server v#{Hooks::VERSION}")
        expect(mock_logger).to receive(:info).with("config: 0 endpoints loaded")
        expect(mock_logger).to receive(:info).with("environment: test")
        expect(mock_logger).to receive(:info).with("available endpoints: ")

        builder.build
      end

      it "logs endpoint information when endpoints are present" do
        endpoints = [
          { path: "/webhook/test1", handler: "Handler1" },
          { path: "/webhook/test2", handler: "Handler2" }
        ]
        allow(Hooks::Core::ConfigLoader).to receive(:load_endpoints).and_return(endpoints)
        allow(Hooks::Core::ConfigValidator).to receive(:validate_endpoints).and_return(endpoints)

        expect(mock_logger).to receive(:info).with("config: 2 endpoints loaded")
        expect(mock_logger).to receive(:info).with("available endpoints: /webhook/test1, /webhook/test2")

        builder.build
      end
    end

    context "error handling" do
      let(:builder) { described_class.new }

      it "raises ConfigurationError when global config validation fails" do
        allow(Hooks::Core::ConfigLoader).to receive(:load).and_return({})
        allow(Hooks::Core::ConfigValidator).to receive(:validate_global_config)
          .and_raise(Hooks::Core::ConfigValidator::ValidationError, "Invalid config")

        expect {
          builder.build
        }.to raise_error(Hooks::Core::ConfigurationError,
                         "Configuration validation failed: Invalid config")
      end

      it "raises ConfigurationError when endpoint validation fails" do
        allow(Hooks::Core::ConfigLoader).to receive(:load).and_return({ endpoints_dir: "/test" })
        allow(Hooks::Core::ConfigValidator).to receive(:validate_global_config).and_return({ endpoints_dir: "/test" })
        allow(Hooks::Core::ConfigLoader).to receive(:load_endpoints).and_return([{}])
        allow(Hooks::Core::ConfigValidator).to receive(:validate_endpoints)
          .and_raise(Hooks::Core::ConfigValidator::ValidationError, "Invalid endpoint")

        expect {
          builder.build
        }.to raise_error(Hooks::Core::ConfigurationError,
                         "Endpoint validation failed: Invalid endpoint")
      end
    end
  end

  describe "#load_and_validate_config" do
    let(:builder) { described_class.new }

    it "is a private method" do
      expect(described_class.private_instance_methods).to include(:load_and_validate_config)
    end
  end

  describe "#load_endpoints" do
    let(:builder) { described_class.new }

    it "is a private method" do
      expect(described_class.private_instance_methods).to include(:load_endpoints)
    end
  end

  describe "ConfigurationError" do
    it "is a StandardError" do
      expect(Hooks::Core::ConfigurationError.new).to be_a(StandardError)
    end

    it "can be raised with a custom message" do
      expect {
        raise Hooks::Core::ConfigurationError, "Custom error"
      }.to raise_error(Hooks::Core::ConfigurationError, "Custom error")
    end
  end
end
