# frozen_string_literal: true

describe Hooks::App::Auth do
  # Create a test class that includes the auth module
  let(:test_class) do
    Class.new do
      include Hooks::App::Auth

      def error!(message, code)
        raise StandardError, "#{message} (#{code})"
      end
    end
  end

  let(:auth_instance) { test_class.new }
  let(:payload) { "test payload" }
  let(:headers) { { "Content-Type" => "application/json" } }

  describe "#validate_auth!" do
    context "when auth config has secret_env_key" do
      let(:endpoint_config) do
        {
          auth: {
            type: "hmac",
            secret_env_key: "TEST_SECRET"
          }
        }
      end

      context "when secret exists in environment" do
        before do
          ENV["TEST_SECRET"] = "test-secret-value"
        end

        after do
          ENV.delete("TEST_SECRET")
        end

        context "with HMAC auth type" do
          it "validates with HMAC plugin when authentication succeeds" do
            allow(Hooks::Plugins::Auth::HMAC).to receive(:valid?).and_return(true)

            expect { auth_instance.validate_auth!(payload, headers, endpoint_config) }
              .not_to raise_error

            expect(Hooks::Plugins::Auth::HMAC).to have_received(:valid?).with(
              payload: payload,
              headers: headers,
              secret: "test-secret-value",
              config: endpoint_config
            )
          end

          it "raises authentication failed error when HMAC validation fails" do
            allow(Hooks::Plugins::Auth::HMAC).to receive(:valid?).and_return(false)

            expect { auth_instance.validate_auth!(payload, headers, endpoint_config) }
              .to raise_error(StandardError, "authentication failed (401)")
          end
        end

        context "with shared_secret auth type" do
          let(:endpoint_config) do
            {
              auth: {
                type: "shared_secret",
                secret_env_key: "TEST_SECRET"
              }
            }
          end

          it "validates with SharedSecret plugin when authentication succeeds" do
            allow(Hooks::Plugins::Auth::SharedSecret).to receive(:valid?).and_return(true)

            expect { auth_instance.validate_auth!(payload, headers, endpoint_config) }
              .not_to raise_error

            expect(Hooks::Plugins::Auth::SharedSecret).to have_received(:valid?).with(
              payload: payload,
              headers: headers,
              secret: "test-secret-value",
              config: endpoint_config
            )
          end

          it "raises authentication failed error when SharedSecret validation fails" do
            allow(Hooks::Plugins::Auth::SharedSecret).to receive(:valid?).and_return(false)

            expect { auth_instance.validate_auth!(payload, headers, endpoint_config) }
              .to raise_error(StandardError, "authentication failed (401)")
          end
        end

        context "with unsupported auth type" do
          let(:endpoint_config) do
            {
              auth: {
                type: "custom",
                secret_env_key: "TEST_SECRET"
              }
            }
          end

          it "raises custom validators not implemented error" do
            expect { auth_instance.validate_auth!(payload, headers, endpoint_config) }
              .to raise_error(StandardError, "Custom validators not implemented in POC (500)")
          end
        end

        context "with case variations in auth type" do
          let(:endpoint_config) do
            {
              auth: {
                type: "HMAC",
                secret_env_key: "TEST_SECRET"
              }
            }
          end

          it "handles uppercase auth type" do
            allow(Hooks::Plugins::Auth::HMAC).to receive(:valid?).and_return(true)

            expect { auth_instance.validate_auth!(payload, headers, endpoint_config) }
              .not_to raise_error
          end
        end
      end

      context "when secret does not exist in environment" do
        let(:endpoint_config) do
          {
            auth: {
              type: "hmac",
              secret_env_key: "NONEXISTENT_SECRET"
            }
          }
        end

        it "raises secret not found error" do
          ENV.delete("NONEXISTENT_SECRET") # Ensure it's not set

          expect { auth_instance.validate_auth!(payload, headers, endpoint_config) }
            .to raise_error(StandardError, "secret 'NONEXISTENT_SECRET' not found in environment (500)")
        end
      end
    end

    context "when auth config has no secret_env_key" do
      let(:endpoint_config) do
        {
          auth: {
            type: "hmac"
          }
        }
      end

      it "returns without validation" do
        expect { auth_instance.validate_auth!(payload, headers, endpoint_config) }
          .not_to raise_error

        # No auth plugins should be called
        expect(Hooks::Plugins::Auth::HMAC).not_to receive(:valid?)
        expect(Hooks::Plugins::Auth::SharedSecret).not_to receive(:valid?)
      end
    end

    context "when auth config has nil secret_env_key" do
      let(:endpoint_config) do
        {
          auth: {
            type: "hmac",
            secret_env_key: nil
          }
        }
      end

      it "returns without validation" do
        expect { auth_instance.validate_auth!(payload, headers, endpoint_config) }
          .not_to raise_error
      end
    end

    context "when auth config has empty secret_env_key" do
      let(:endpoint_config) do
        {
          auth: {
            type: "hmac",
            secret_env_key: ""
          }
        }
      end

      it "raises secret not found error for empty string" do
        ENV.delete("") # Ensure empty string key is not set
        
        expect { auth_instance.validate_auth!(payload, headers, endpoint_config) }
          .to raise_error(StandardError, "secret '' not found in environment (500)")
      end
    end
  end
end