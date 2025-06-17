# frozen_string_literal: true

require_relative "../../../spec_helper"

describe "Configuration Validator Security Tests" do
  describe Hooks::Core::ConfigValidator do
    describe "#validate_endpoint_config" do
      context "with secure handler names" do
        it "accepts valid handler names" do
          valid_configs = [
            { path: "/webhook", handler: "my_handler" },
            { path: "/webhook", handler: "github_handler" },
            { path: "/webhook", handler: "team_1_handler" },
            { path: "/webhook", handler: "webhook_handler" },
            { path: "/webhook", handler: "custom_webhook_handler" },
            { path: "/webhook", handler: "handler_123" },
            { path: "/webhook", handler: "my_handler" }
          ]

          valid_configs.each do |config|
            expect do
              described_class.validate_endpoint_config(config)
            end.not_to raise_error
          end
        end

        it "rejects dangerous system class names" do
          dangerous_configs = Hooks::Security::DANGEROUS_CLASSES.map do |class_name|
            # Convert PascalCase to snake_case for config
            snake_case_name = class_name.gsub(/([A-Z])/, '_\1').downcase.sub(/^_/, '')
            { path: "/webhook", handler: snake_case_name }
          end

          dangerous_configs.each do |config|
            expect do
              described_class.validate_endpoint_config(config)
            end.to raise_error(Hooks::Core::ConfigValidator::ValidationError, /Invalid handler name/)
          end
        end

        it "rejects handler names with invalid format" do
          invalid_configs = [
            { path: "/webhook", handler: "Handler" },           # uppercase start
            { path: "/webhook", handler: "123handler" },        # number start
            { path: "/webhook", handler: "_handler" },          # underscore start
            { path: "/webhook", handler: "handler$test" },      # special characters
            { path: "/webhook", handler: "handler.test" },      # dots
            { path: "/webhook", handler: "handler/test" },      # slashes
            { path: "/webhook", handler: "handler test" },      # spaces
            { path: "/webhook", handler: "handler\ntest" },     # newlines
            { path: "/webhook", handler: "handlerTest" },       # camelCase
            { path: "/webhook", handler: "HandlerTest" }        # PascalCase
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
            { path: "/webhook1", handler: "valid_handler" },
            { path: "/webhook2", handler: "File" },  # This should fail (PascalCase)
            { path: "/webhook3", handler: "another_valid_handler" }
          ]

          expect do
            described_class.validate_endpoints(endpoints)
          end.to raise_error(Hooks::Core::ConfigValidator::ValidationError, /Endpoint 1.*Invalid handler name/)
        end
      end
    end
  end
end
