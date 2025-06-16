# frozen_string_literal: true

require_relative "../../../../spec_helper"

describe Hooks::App::Auth do
  let(:log) { instance_double(Logger).as_null_object }
  let(:test_class) do
    Class.new do
      include Hooks::App::Auth

      def error!(message, code)
        raise StandardError, "#{message} (#{code})"
      end
    end
  end

  let(:instance) { test_class.new }
  let(:payload) { '{"test": "data"}' }
  let(:headers) { { "Content-Type" => "application/json" } }

  before(:each) do
    Hooks::Log.instance = log
  end

  describe "#validate_auth!" do
    context "when testing security vulnerabilities" do
      context "with missing auth configuration" do
        it "rejects request with no auth config" do
          endpoint_config = {}
          global_config = {}
          request_context = { request_id: "test-request-id" }
          log_msg = "authentication configuration missing or invalid - request_id: #{request_context[:request_id]}"

          expect(log).to receive(:error).with(log_msg)

          expect do
            instance.validate_auth!(payload, headers, endpoint_config, global_config, request_context)
          end.to raise_error(StandardError, /authentication configuration missing or invalid/)
        end

        it "rejects request with nil auth config" do
          endpoint_config = { auth: nil }

          expect do
            instance.validate_auth!(payload, headers, endpoint_config)
          end.to raise_error(StandardError, /authentication configuration missing or invalid/)
        end

        it "rejects request with empty auth config" do
          endpoint_config = { auth: {} }

          expect do
            instance.validate_auth!(payload, headers, endpoint_config)
          end.to raise_error(StandardError, /authentication configuration missing or invalid/)
        end
      end

      context "with missing auth type" do
        it "rejects request with nil type" do
          endpoint_config = { auth: { type: nil } }

          expect do
            instance.validate_auth!(payload, headers, endpoint_config)
          end.to raise_error(StandardError, /authentication configuration missing or invalid/)
        end

        it "rejects request with non-string type" do
          endpoint_config = { auth: { type: 123 } }

          expect do
            instance.validate_auth!(payload, headers, endpoint_config)
          end.to raise_error(StandardError, /authentication configuration missing or invalid/)
        end

        it "rejects request with empty string type" do
          endpoint_config = { auth: { type: "" } }

          expect do
            instance.validate_auth!(payload, headers, endpoint_config)
          end.to raise_error(StandardError, /authentication configuration missing or invalid/)
        end
      end

      context "with missing secret configuration" do
        it "rejects request with missing secret_env_key" do
          endpoint_config = { auth: { type: "hmac" } }

          expect do
            instance.validate_auth!(payload, headers, endpoint_config)
          end.to raise_error(StandardError, /authentication failed/)
        end

        it "rejects request with nil secret_env_key" do
          endpoint_config = { auth: { type: "hmac", secret_env_key: nil } }

          expect do
            instance.validate_auth!(payload, headers, endpoint_config)
          end.to raise_error(StandardError, /authentication failed/)
        end

        it "rejects request with empty secret_env_key" do
          endpoint_config = { auth: { type: "hmac", secret_env_key: "" } }

          expect do
            instance.validate_auth!(payload, headers, endpoint_config)
          end.to raise_error(StandardError, /authentication failed/)
        end

        it "rejects request with whitespace-only secret_env_key" do
          endpoint_config = { auth: { type: "hmac", secret_env_key: "   " } }

          expect do
            instance.validate_auth!(payload, headers, endpoint_config)
          end.to raise_error(StandardError, /authentication failed/)
        end

        it "rejects request with non-string secret_env_key" do
          endpoint_config = { auth: { type: "hmac", secret_env_key: 123 } }

          expect do
            instance.validate_auth!(payload, headers, endpoint_config)
          end.to raise_error(StandardError, /authentication failed/)
        end
      end

      context "with missing environment variable" do
        it "uses generic error message for missing secrets" do
          ENV.delete("NONEXISTENT_SECRET")
          endpoint_config = { auth: { type: "hmac", secret_env_key: "NONEXISTENT_SECRET" } }

          expect do
            instance.validate_auth!(payload, headers, endpoint_config)
          end.to raise_error(StandardError, /authentication failed/)
        end

        it "does not leak the environment variable name in error" do
          ENV.delete("SECRET_WEBHOOK_KEY")
          endpoint_config = { auth: { type: "hmac", secret_env_key: "SECRET_WEBHOOK_KEY" } }

          expect do
            instance.validate_auth!(payload, headers, endpoint_config)
          end.to raise_error do |error|
            # Ensure error message is generic and doesn't leak the environment variable name
            expect(error.message).not_to include("SECRET_WEBHOOK_KEY")
            expect(error.message).to match(/authentication failed/)
          end
        end
      end

      context "with valid configuration but invalid secrets" do
        before do
          ENV["TEST_WEBHOOK_SECRET"] = "test-secret"
        end

        after do
          ENV.delete("TEST_WEBHOOK_SECRET")
        end

        it "properly validates HMAC authentication" do
          endpoint_config = {
            auth: {
              type: "hmac",
              secret_env_key: "TEST_WEBHOOK_SECRET",
              header: "X-Signature"
            }
          }
          invalid_headers = headers.merge("X-Signature" => "invalid-signature")

          expect do
            instance.validate_auth!(payload, invalid_headers, endpoint_config)
          end.to raise_error(StandardError, /authentication failed/)
        end

        it "properly validates shared_secret authentication" do
          endpoint_config = {
            auth: {
              type: "shared_secret",
              secret_env_key: "TEST_WEBHOOK_SECRET",
              header: "Authorization"
            }
          }

          expect do
            instance.validate_auth!(payload, headers, endpoint_config)
          end.to raise_error(StandardError, /authentication failed/)
        end
      end

      context "with edge case auth types" do
        before do
          ENV["TEST_WEBHOOK_SECRET"] = "test-secret"
        end

        after do
          ENV.delete("TEST_WEBHOOK_SECRET")
        end

        it "handles case-insensitive auth types" do
          endpoint_config = {
            auth: {
              type: "HMAC",
              secret_env_key: "TEST_WEBHOOK_SECRET",
              header: "X-Signature"
            }
          }
          invalid_headers = headers.merge("X-Signature" => "invalid")

          expect do
            instance.validate_auth!(payload, invalid_headers, endpoint_config)
          end.to raise_error(StandardError, /authentication failed/)
        end

        it "rejects unknown auth types" do
          endpoint_config = {
            auth: {
              type: "unknown_type",
              secret_env_key: "TEST_WEBHOOK_SECRET"
            }
          }

          expect do
            instance.validate_auth!(payload, headers, endpoint_config)
          end.to raise_error(StandardError, /unsupported auth type/)
        end
      end
    end
  end
end
