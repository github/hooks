# frozen_string_literal: true

require_relative "../../../spec_helper"

describe "Handler Loading Security Tests" do
  let(:test_class) do
    Class.new do
      include Hooks::App::Helpers

      def error!(message, code)
        raise StandardError, "#{message} (#{code})"
      end

      def headers
        {}
      end

      def env
        {}
      end
    end
  end

  let(:instance) { test_class.new }
  let(:handler_dir) { "/tmp/test_handlers" }

  before do
    # Create test handler directory
    FileUtils.mkdir_p(handler_dir)
  end

  after do
    # Clean up test handler directory
    FileUtils.rm_rf(handler_dir) if File.exist?(handler_dir)
  end

  describe "#load_handler security" do
    context "with malicious handler class names" do
      it "rejects system class names" do
        Hooks::Security::DANGEROUS_CLASSES.each do |class_name|
          expect do
            instance.load_handler(class_name, handler_dir)
          end.to raise_error(StandardError, /invalid handler class name/)
        end
      end

      it "rejects network-related class names" do
        network_classes = %w[IO Socket TCPSocket UDPSocket BasicSocket]
        # Verify these are all in our dangerous classes list
        network_classes.each { |cls| expect(Hooks::Security::DANGEROUS_CLASSES).to include(cls) }

        network_classes.each do |class_name|
          expect do
            instance.load_handler(class_name, handler_dir)
          end.to raise_error(StandardError, /invalid handler class name/)
        end
      end

      it "rejects process and system class names" do
        system_classes = %w[Process Thread Fiber Mutex ConditionVariable]
        # Verify these are all in our dangerous classes list
        system_classes.each { |cls| expect(Hooks::Security::DANGEROUS_CLASSES).to include(cls) }

        system_classes.each do |class_name|
          expect do
            instance.load_handler(class_name, handler_dir)
          end.to raise_error(StandardError, /invalid handler class name/)
        end
      end

      it "rejects serialization class names" do
        serialization_classes = %w[Marshal YAML JSON Pathname]
        # Verify these are all in our dangerous classes list
        serialization_classes.each { |cls| expect(Hooks::Security::DANGEROUS_CLASSES).to include(cls) }

        serialization_classes.each do |class_name|
          expect do
            instance.load_handler(class_name, handler_dir)
          end.to raise_error(StandardError, /invalid handler class name/)
        end
      end

      it "rejects handler names with invalid characters" do
        invalid_names = [
          "Handler$Test", # Special characters
          "Handler.Test", # Dots
          "Handler/Test", # Slashes
          "Handler Test", # Spaces
          "Handler\nTest", # Newlines
          "Handler\tTest", # Tabs
          "handler_test", # Lowercase start
          "123Handler", # Number start
          "_Handler", # Underscore start
          ""  # Empty string
        ]

        invalid_names.each do |name|
          expect do
            instance.load_handler(name, handler_dir)
          end.to raise_error(StandardError, /invalid handler class name/)
        end
      end

      it "rejects nil and non-string handler names" do
        invalid_values = [nil, 123, [], {}, true, false]

        invalid_values.each do |value|
          expect do
            instance.load_handler(value, handler_dir)
          end.to raise_error(StandardError, /invalid handler class name/)
        end
      end
    end

    context "with path traversal attempts" do
      it "rejects handler names that could escape the handler directory" do
        # These should be rejected by the class name validation
        path_traversal_attempts = [
          "../EvilHandler",
          "../../EvilHandler",
          "../etc/passwd",
          "Handler/../EvilHandler"
        ]

        path_traversal_attempts.each do |name|
          expect do
            instance.load_handler(name, handler_dir)
          end.to raise_error(StandardError, /invalid handler class name/)
        end
      end
    end

    context "with valid handler class names" do
      it "accepts properly formatted handler names" do
        valid_names = [
          "MyHandler",
          "GitHubHandler",
          "Team1Handler",
          "WebhookHandler",
          "CustomWebhookHandler",
          "Handler123",
          "My_Handler",
          "A" # Single letter (edge case)
        ]

        valid_names.each do |name|
          # Should pass name validation but fail because file doesn't exist
          expect do
            instance.load_handler(name, handler_dir)
          end.to raise_error(LoadError, /Handler .* not found/)
        end
      end

      context "with valid handler file and class" do
        let(:handler_name) { "TestHandler" }
        let(:handler_file) { File.join(handler_dir, "test_handler.rb") }

        before do
          # Create a valid handler file
          File.write(handler_file, <<~RUBY)
            class TestHandler < Hooks::Handlers::Base
              def call(payload:, headers:, config:)
                { message: "test" }
              end
            end
          RUBY
        end

        it "successfully loads valid handlers that inherit from Base" do
          handler = instance.load_handler(handler_name, handler_dir)
          expect(handler).to be_a(TestHandler)
          expect(handler).to be_a(Hooks::Handlers::Base)
        end
      end

      context "with invalid handler class inheritance" do
        let(:handler_name) { "BadHandler" }
        let(:handler_file) { File.join(handler_dir, "bad_handler.rb") }

        before do
          # Create a handler that doesn't inherit from Base
          File.write(handler_file, <<~RUBY)
            class BadHandler
              def call(payload:, headers:, config:)
                { message: "bad" }
              end
            end
          RUBY
        end

        it "rejects handlers that don't inherit from Hooks::Handlers::Base" do
          expect do
            instance.load_handler(handler_name, handler_dir)
          end.to raise_error(StandardError, /handler class must inherit from Hooks::Handlers::Base/)
        end
      end
    end
  end

  describe "#valid_handler_class_name?" do
    it "validates handler names correctly" do
      # This tests the private method by accessing it through send
      # (normally we wouldn't test private methods, but this is critical security validation)
      valid_names = %w[MyHandler GitHubHandler Team1Handler A Handler123]
      invalid_names = ["File", "handler", "123Handler", "", nil, " ", "Handler$", "Handler.Test"]

      valid_names.each do |name|
        result = instance.send(:valid_handler_class_name?, name)
        expect(result).to be(true), "#{name} should be valid"
      end

      invalid_names.each do |name|
        result = instance.send(:valid_handler_class_name?, name)
        expect(result).to be(false), "#{name} should be invalid"
      end
    end
  end
end
