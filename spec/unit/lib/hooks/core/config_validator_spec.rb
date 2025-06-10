# frozen_string_literal: true

require_relative "../../../spec_helper"

describe Hooks::Core::ConfigValidator do
  describe ".validate_global_config" do
    context "with valid configuration" do
      it "returns validated configuration with all optional fields" do
        config = {
          handler_dir: "./custom_handlers",
          log_level: "debug",
          request_limit: 2_048_000,
          request_timeout: 45,
          root_path: "/custom/webhooks",
          health_path: "/custom/health",
          version_path: "/custom/version",
          environment: "development", 
          endpoints_dir: "./custom/endpoints",
          use_catchall_route: true,
          symbolize_payload: false,
          normalize_headers: false
        }

        result = described_class.validate_global_config(config)

        expect(result).to eq(config)
      end

      it "returns validated configuration with minimal fields" do
        config = {}

        result = described_class.validate_global_config(config)

        expect(result).to eq({})
      end

      it "accepts production environment" do
        config = { environment: "production" }

        result = described_class.validate_global_config(config)

        expect(result).to eq(config)
      end

      it "accepts valid log levels" do
        %w[debug info warn error].each do |log_level|
          config = { log_level: log_level }

          result = described_class.validate_global_config(config)

          expect(result[:log_level]).to eq(log_level)
        end
      end
    end

    context "with invalid configuration" do
      it "raises ValidationError for invalid log level" do
        config = { log_level: "invalid" }

        expect {
          described_class.validate_global_config(config)
        }.to raise_error(described_class::ValidationError, /Invalid global configuration/)
      end

      it "raises ValidationError for invalid environment" do
        config = { environment: "staging" }

        expect {
          described_class.validate_global_config(config)
        }.to raise_error(described_class::ValidationError, /Invalid global configuration/)
      end

      it "raises ValidationError for zero request_limit" do
        config = { request_limit: 0 }

        expect {
          described_class.validate_global_config(config)
        }.to raise_error(described_class::ValidationError, /Invalid global configuration/)
      end

      it "raises ValidationError for negative request_limit" do
        config = { request_limit: -100 }

        expect {
          described_class.validate_global_config(config)
        }.to raise_error(described_class::ValidationError, /Invalid global configuration/)
      end

      it "raises ValidationError for zero request_timeout" do
        config = { request_timeout: 0 }

        expect {
          described_class.validate_global_config(config)
        }.to raise_error(described_class::ValidationError, /Invalid global configuration/)
      end

      it "raises ValidationError for negative request_timeout" do
        config = { request_timeout: -30 }

        expect {
          described_class.validate_global_config(config)
        }.to raise_error(described_class::ValidationError, /Invalid global configuration/)
      end

      it "raises ValidationError for empty string values" do
        config = {
          handler_dir: "",
          root_path: "",
          health_path: ""
        }

        expect {
          described_class.validate_global_config(config)
        }.to raise_error(described_class::ValidationError, /Invalid global configuration/)
      end

      it "coerces boolean-like string values" do
        config = {
          use_catchall_route: "true",
          symbolize_payload: "false",
          normalize_headers: "1"
        }

        result = described_class.validate_global_config(config)

        expect(result[:use_catchall_route]).to be true
        expect(result[:symbolize_payload]).to be false
        expect(result[:normalize_headers]).to be true # "1" gets coerced to true
      end

      it "raises ValidationError for non-string paths" do
        config = {
          handler_dir: 123,
          root_path: [],
          endpoints_dir: {}
        }

        expect {
          described_class.validate_global_config(config)
        }.to raise_error(described_class::ValidationError, /Invalid global configuration/)
      end

      it "coerces string numeric values" do
        config = {
          request_limit: "1024",
          request_timeout: "30"
        }

        result = described_class.validate_global_config(config)

        expect(result[:request_limit]).to eq(1024)
        expect(result[:request_timeout]).to eq(30)
      end

      it "raises ValidationError for invalid boolean string values" do
        config = { use_catchall_route: "invalid_boolean" }

        expect {
          described_class.validate_global_config(config)
        }.to raise_error(described_class::ValidationError, /Invalid global configuration/)
      end

      it "raises ValidationError for non-numeric string values for integers" do
        config = { request_limit: "not_a_number" }

        expect {
          described_class.validate_global_config(config)
        }.to raise_error(described_class::ValidationError, /Invalid global configuration/)
      end

      it "coerces float values to integers by truncating" do
        config = { request_timeout: 30.5 }

        result = described_class.validate_global_config(config)

        expect(result[:request_timeout]).to eq(30)
      end
    end
  end

  describe ".validate_endpoint_config" do
    context "with valid configuration" do
      it "returns validated configuration with required fields only" do
        config = {
          path: "/webhook/simple",
          handler: "SimpleHandler"
        }

        result = described_class.validate_endpoint_config(config)

        expect(result).to eq(config)
      end

      it "returns validated configuration with request validator" do
        config = {
          path: "/webhook/secure",
          handler: "SecureHandler",
          request_validator: {
            type: "hmac",
            secret_env_key: "WEBHOOK_SECRET",
            header: "X-Hub-Signature-256",
            algorithm: "sha256",
            timestamp_header: "X-Timestamp",
            timestamp_tolerance: 300,
            format: "algorithm=signature",
            version_prefix: "v0",
            payload_template: "v0:{timestamp}:{body}"
          }
        }

        result = described_class.validate_endpoint_config(config)

        expect(result).to eq(config)
      end

      it "returns validated configuration with opts hash" do
        config = {
          path: "/webhook/custom",
          handler: "CustomHandler",
          opts: {
            custom_option: "value",
            another_option: 123
          }
        }

        result = described_class.validate_endpoint_config(config)

        expect(result).to eq(config)
      end

      it "returns validated configuration with all optional fields" do
        config = {
          path: "/webhook/full",
          handler: "FullHandler",
          request_validator: {
            type: "custom_validator",
            secret_env_key: "SECRET",
            header: "X-Signature"
          },
          opts: {
            timeout: 60
          }
        }

        result = described_class.validate_endpoint_config(config)

        expect(result).to eq(config)
      end
    end

    context "with invalid configuration" do
      it "raises ValidationError for missing path" do
        config = { handler: "TestHandler" }

        expect {
          described_class.validate_endpoint_config(config)
        }.to raise_error(described_class::ValidationError, /Invalid endpoint configuration/)
      end

      it "raises ValidationError for missing handler" do
        config = { path: "/webhook/test" }

        expect {
          described_class.validate_endpoint_config(config)
        }.to raise_error(described_class::ValidationError, /Invalid endpoint configuration/)
      end

      it "raises ValidationError for empty path" do
        config = {
          path: "",
          handler: "TestHandler"
        }

        expect {
          described_class.validate_endpoint_config(config)
        }.to raise_error(described_class::ValidationError, /Invalid endpoint configuration/)
      end

      it "raises ValidationError for empty handler" do
        config = {
          path: "/webhook/test",
          handler: ""
        }

        expect {
          described_class.validate_endpoint_config(config)
        }.to raise_error(described_class::ValidationError, /Invalid endpoint configuration/)
      end

      it "raises ValidationError for non-string path" do
        config = {
          path: 123,
          handler: "TestHandler"
        }

        expect {
          described_class.validate_endpoint_config(config)
        }.to raise_error(described_class::ValidationError, /Invalid endpoint configuration/)
      end

      it "raises ValidationError for non-string handler" do
        config = {
          path: "/webhook/test",
          handler: []
        }

        expect {
          described_class.validate_endpoint_config(config)
        }.to raise_error(described_class::ValidationError, /Invalid endpoint configuration/)
      end

      it "raises ValidationError for request_validator missing required type" do
        config = {
          path: "/webhook/test",
          handler: "TestHandler",
          request_validator: {
            header: "X-Signature"
          }
        }

        expect {
          described_class.validate_endpoint_config(config)
        }.to raise_error(described_class::ValidationError, /Invalid endpoint configuration/)
      end

      it "raises ValidationError for request_validator with empty type" do
        config = {
          path: "/webhook/test",
          handler: "TestHandler",
          request_validator: {
            type: ""
          }
        }

        expect {
          described_class.validate_endpoint_config(config)
        }.to raise_error(described_class::ValidationError, /Invalid endpoint configuration/)
      end

      it "raises ValidationError for non-hash request_validator" do
        config = {
          path: "/webhook/test",
          handler: "TestHandler",
          request_validator: "hmac"
        }

        expect {
          described_class.validate_endpoint_config(config)
        }.to raise_error(described_class::ValidationError, /Invalid endpoint configuration/)
      end

      it "raises ValidationError for non-hash opts" do
        config = {
          path: "/webhook/test",
          handler: "TestHandler",
          opts: "invalid"
        }

        expect {
          described_class.validate_endpoint_config(config)
        }.to raise_error(described_class::ValidationError, /Invalid endpoint configuration/)
      end

      it "raises ValidationError for zero timestamp_tolerance" do
        config = {
          path: "/webhook/test",
          handler: "TestHandler",
          request_validator: {
            type: "hmac",
            timestamp_tolerance: 0
          }
        }

        expect {
          described_class.validate_endpoint_config(config)
        }.to raise_error(described_class::ValidationError, /Invalid endpoint configuration/)
      end

      it "raises ValidationError for negative timestamp_tolerance" do
        config = {
          path: "/webhook/test",
          handler: "TestHandler",
          request_validator: {
            type: "hmac",
            timestamp_tolerance: -100
          }
        }

        expect {
          described_class.validate_endpoint_config(config)
        }.to raise_error(described_class::ValidationError, /Invalid endpoint configuration/)
      end

      it "raises ValidationError for empty string fields in request_validator" do
        config = {
          path: "/webhook/test",
          handler: "TestHandler",
          request_validator: {
            type: "hmac",
            secret_env_key: "",
            header: "",
            algorithm: ""
          }
        }

        expect {
          described_class.validate_endpoint_config(config)
        }.to raise_error(described_class::ValidationError, /Invalid endpoint configuration/)
      end
    end
  end

  describe ".validate_endpoints" do
    context "with valid endpoints array" do
      it "returns validated endpoints for empty array" do
        endpoints = []

        result = described_class.validate_endpoints(endpoints)

        expect(result).to eq([])
      end

      it "returns validated endpoints for single valid endpoint" do
        endpoints = [
          {
            path: "/webhook/test",
            handler: "TestHandler"
          }
        ]

        result = described_class.validate_endpoints(endpoints)

        expect(result).to eq(endpoints)
      end

      it "returns validated endpoints for multiple valid endpoints" do
        endpoints = [
          {
            path: "/webhook/test1",
            handler: "TestHandler1"
          },
          {
            path: "/webhook/test2",
            handler: "TestHandler2",
            request_validator: {
              type: "hmac",
              header: "X-Hub-Signature"
            }
          }
        ]

        result = described_class.validate_endpoints(endpoints)

        expect(result).to eq(endpoints)
      end
    end

    context "with invalid endpoints array" do
      it "raises ValidationError with endpoint index for first invalid endpoint" do
        endpoints = [
          {
            path: "/webhook/valid",
            handler: "ValidHandler"
          },
          {
            path: "/webhook/invalid",
            # missing handler
          },
          {
            path: "/webhook/another",
            handler: "AnotherHandler"
          }
        ]

        expect {
          described_class.validate_endpoints(endpoints)
        }.to raise_error(described_class::ValidationError, /Endpoint 1:.*Invalid endpoint configuration/)
      end

      it "raises ValidationError with endpoint index for last invalid endpoint" do
        endpoints = [
          {
            path: "/webhook/valid1",
            handler: "ValidHandler1"
          },
          {
            path: "/webhook/valid2",
            handler: "ValidHandler2"
          },
          {
            handler: "InvalidHandler"
            # missing path
          }
        ]

        expect {
          described_class.validate_endpoints(endpoints)
        }.to raise_error(described_class::ValidationError, /Endpoint 2:.*Invalid endpoint configuration/)
      end

      it "raises ValidationError for endpoint with invalid request_validator" do
        endpoints = [
          {
            path: "/webhook/test",
            handler: "TestHandler",
            request_validator: {
              # missing required type
              header: "X-Signature"
            }
          }
        ]

        expect {
          described_class.validate_endpoints(endpoints)
        }.to raise_error(described_class::ValidationError, /Endpoint 0:.*Invalid endpoint configuration/)
      end
    end
  end

  describe "ValidationError" do
    it "is a StandardError" do
      expect(described_class::ValidationError.new).to be_a(StandardError)
    end

    it "can be raised with a custom message" do
      expect {
        raise described_class::ValidationError, "Custom validation error"
      }.to raise_error(described_class::ValidationError, "Custom validation error")
    end
  end
end