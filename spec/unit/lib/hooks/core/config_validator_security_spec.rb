# frozen_string_literal: true

require_relative "../../../spec_helper"

describe "Configuration Validator Security Tests" do
  describe Hooks::Core::ConfigValidator do
    describe "#validate_endpoint_config" do
      context "with secure handler names" do
        it "accepts valid handler names" do
          valid_configs = [
            { path: "/webhook", handler: "MyHandler" },
            { path: "/webhook", handler: "GitHubHandler" },
            { path: "/webhook", handler: "Team1Handler" },
            { path: "/webhook", handler: "WebhookHandler" },
            { path: "/webhook", handler: "CustomWebhookHandler" },
            { path: "/webhook", handler: "Handler123" },
            { path: "/webhook", handler: "My_Handler" }
          ]

          valid_configs.each do |config|
            expect do
              described_class.validate_endpoint_config(config)
            end.not_to raise_error
          end
        end

        it "rejects dangerous system class names" do
          dangerous_configs = [
            { path: "/webhook", handler: "File" },
            { path: "/webhook", handler: "Dir" },
            { path: "/webhook", handler: "Kernel" },
            { path: "/webhook", handler: "Object" },
            { path: "/webhook", handler: "Class" },
            { path: "/webhook", handler: "Module" },
            { path: "/webhook", handler: "Proc" },
            { path: "/webhook", handler: "Method" },
            { path: "/webhook", handler: "IO" },
            { path: "/webhook", handler: "Socket" },
            { path: "/webhook", handler: "TCPSocket" },
            { path: "/webhook", handler: "Process" },
            { path: "/webhook", handler: "Thread" },
            { path: "/webhook", handler: "Marshal" },
            { path: "/webhook", handler: "YAML" },
            { path: "/webhook", handler: "JSON" }
          ]

          dangerous_configs.each do |config|
            expect do
              described_class.validate_endpoint_config(config)
            end.to raise_error(Hooks::Core::ConfigValidator::ValidationError, /Invalid handler name/)
          end
        end

        it "rejects handler names with invalid format" do
          invalid_configs = [
            { path: "/webhook", handler: "handler" },           # lowercase start
            { path: "/webhook", handler: "123Handler" },        # number start
            { path: "/webhook", handler: "_Handler" },          # underscore start
            { path: "/webhook", handler: "Handler$Test" },      # special characters
            { path: "/webhook", handler: "Handler.Test" },      # dots
            { path: "/webhook", handler: "Handler/Test" },      # slashes
            { path: "/webhook", handler: "Handler Test" },      # spaces
            { path: "/webhook", handler: "Handler\nTest" }      # newlines
          ]

          invalid_configs.each do |config|
            expect do
              described_class.validate_endpoint_config(config)
            end.to raise_error(Hooks::Core::ConfigValidator::ValidationError, /Invalid handler name/)
          end
        end

        it "rejects empty or whitespace-only handler names" do
          invalid_configs = [
            { path: "/webhook", handler: "" },                  # empty string
            { path: "/webhook", handler: "   " }                # whitespace only
          ]

          invalid_configs.each do |config|
            expect do
              described_class.validate_endpoint_config(config)
            end.to raise_error(Hooks::Core::ConfigValidator::ValidationError)
          end
        end

        it "rejects nil and non-string handler names" do
          invalid_configs = [
            { path: "/webhook", handler: nil },
            { path: "/webhook", handler: 123 },
            { path: "/webhook", handler: [] },
            { path: "/webhook", handler: {} },
            { path: "/webhook", handler: true }
          ]

          invalid_configs.each do |config|
            expect do
              described_class.validate_endpoint_config(config)
            end.to raise_error(Hooks::Core::ConfigValidator::ValidationError)
          end
        end
      end

      context "with endpoint arrays" do
        it "validates all endpoints in an array and reports the problematic one" do
          endpoints = [
            { path: "/webhook1", handler: "ValidHandler" },
            { path: "/webhook2", handler: "File" },  # This should fail
            { path: "/webhook3", handler: "AnotherValidHandler" }
          ]

          expect do
            described_class.validate_endpoints(endpoints)
          end.to raise_error(Hooks::Core::ConfigValidator::ValidationError, /Endpoint 1.*Invalid handler name/)
        end
      end
    end
  end
end
