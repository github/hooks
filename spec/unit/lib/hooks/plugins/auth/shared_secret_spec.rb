# frozen_string_literal: true

require_relative "../../../../spec_helper"

describe Hooks::Plugins::Auth::SharedSecret do
  let(:secret) { "my-super-secret-key-12345" }
  let(:payload) { '{"foo":"bar"}' }
  let(:default_header) { "Authorization" }
  let(:default_config) do
    {
      auth: {
        header: default_header,
        secret_env_key: "SUPER_WEBHOOK_SECRET"
      }
    }
  end
  let(:log) { instance_double(Logger).as_null_object }

  def valid_with(args = {})
    args = { config: default_config }.merge(args)
    described_class.valid?(payload:, **args)
  end

  before(:each) do
    Hooks::Log.instance = log
  end

  before do
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with("SUPER_WEBHOOK_SECRET").and_return(secret)
  end

  describe ".valid?" do
    context "with default Authorization header" do
      let(:headers) { { default_header => secret } }

      it "returns true for a valid shared secret" do
        expect(valid_with(headers:)).to be true
      end

      it "returns false for an invalid shared secret" do
        bad_headers = { default_header => "wrong-secret" }
        expect(valid_with(headers: bad_headers)).to be false
      end

      it "returns false if secret header is missing" do
        expect(valid_with(headers: {})).to be false
      end

      it "returns false if secret is nil or empty" do
        # Test nil secret via environment variable
        allow(ENV).to receive(:[]).with("SUPER_WEBHOOK_SECRET").and_return(nil)
        expect(valid_with(headers:)).to be false

        # Test empty secret via environment variable
        allow(ENV).to receive(:[]).with("SUPER_WEBHOOK_SECRET").and_return("")
        expect(valid_with(headers:)).to be false
      end

      it "normalizes header names to lowercase" do
        upcase_headers = { default_header.upcase => secret }
        expect(valid_with(headers: upcase_headers)).to be true

        downcase_headers = { default_header.downcase => secret }
        expect(valid_with(headers: downcase_headers)).to be true

        mixed_case_headers = { "aUtHoRiZaTiOn" => secret }
        expect(valid_with(headers: mixed_case_headers)).to be true
      end

      it "rejects secrets with leading/trailing whitespace for security" do
        # Security check: reject raw values with whitespace to prevent certain attacks
        padded_secret = "  #{secret}  "
        padded_headers = { default_header => padded_secret }

        # The validator should reject this because the raw value has whitespace
        expect(valid_with(headers: padded_headers)).to be false

        # Also test various whitespace patterns
        expect(valid_with(headers: { default_header => " #{secret}" })).to be false
        expect(valid_with(headers: { default_header => "#{secret} " })).to be false
        expect(valid_with(headers: { default_header => "\t#{secret}\t" })).to be false
      end

      it "rejects secrets with control characters" do
        bad_headers = { default_header => "secret\x00with\x01null" }
        expect(valid_with(headers: bad_headers)).to be false

        bad_headers = { default_header => "secret\nwith\nnewline" }
        expect(valid_with(headers: bad_headers)).to be false

        bad_headers = { default_header => "secret\twith\ttab" }
        expect(valid_with(headers: bad_headers)).to be false
      end

      it "handles empty header values" do
        empty_headers = { default_header => "" }
        expect(valid_with(headers: empty_headers)).to be false

        nil_headers = { default_header => nil }
        expect(valid_with(headers: nil_headers)).to be false
      end

      it "returns false for secrets exceeding maximum length limit" do
        # Create secret larger than MAX_HEADER_VALUE_LENGTH (1024 + 1 characters)
        oversized_secret = "a" * (1024 + 1)
        oversized_headers = { default_header => oversized_secret }
        expect(log).to receive(:warn).with(/exceeds maximum length/)
        expect(valid_with(headers: oversized_headers)).to be false
      end

      it "returns false for payloads exceeding maximum size limit" do
        # Create payload larger than MAX_PAYLOAD_SIZE (10MB + 1 byte)
        oversized_payload = "a" * (10 * 1024 * 1024 + 1)
        headers = { default_header => secret }
        expect(log).to receive(:warn).with(/Payload size exceeds maximum limit/)
        expect(valid_with(payload: oversized_payload, headers: headers)).to be false
      end
    end

    context "with custom header configuration" do
      let(:custom_header) { "X-API-Key" }
      let(:custom_config) do
        {
          auth: {
            header: custom_header
          }
        }
      end
      let(:headers) { { custom_header => secret } }

      it "returns true for valid secret in custom header" do
        # TODO
      end

      it "returns false when secret is in wrong header" do
        wrong_headers = { "Authorization" => secret }
        expect(valid_with(headers: wrong_headers, config: custom_config)).to be false
      end

      it "supports case-insensitive custom header matching" do
        # TODO
      end
    end

    context "with no configuration" do
      let(:no_config) { {} }
      let(:headers) { { "Authorization" => secret } }

      it "uses default Authorization header when no config provided" do
        # TODO
      end

      it "returns false when secret is in non-default header and no config" do
        custom_headers = { "X-API-Key" => secret }
        expect(valid_with(headers: custom_headers, config: no_config)).to be false
      end
    end

    context "with invalid configurations" do
      it "handles nil config gracefully" do
        headers = { "Authorization" => secret }
        expect(valid_with(headers:, config: nil)).to be false
      end

      it "handles config without auth section" do
        # TODO
      end
    end

    context "with edge case inputs" do
      let(:headers) { { default_header => secret } }

      it "handles different header types" do
        # String keys (most common)
        string_headers = { "Authorization" => secret }
        expect(valid_with(headers: string_headers)).to be true

        # Symbol keys
        symbol_headers = { Authorization: secret }
        expect(valid_with(headers: symbol_headers)).to be true

        # Mixed keys
        mixed_headers = { "authorization" => secret }
        expect(valid_with(headers: mixed_headers)).to be true
      end

      it "handles non-hash headers" do
        expect(valid_with(headers: nil)).to be false
        expect(valid_with(headers: "not a hash")).to be false
        expect(valid_with(headers: [])).to be false
        expect(valid_with(headers: 123)).to be false
      end

      it "handles different secret types" do
        headers = { default_header => "123" }

        # String secret
        allow(ENV).to receive(:[]).with("SUPER_WEBHOOK_SECRET").and_return("123")
        expect(valid_with(headers:)).to be true

        # Test that secrets are treated as strings from environment
        allow(ENV).to receive(:[]).with("SUPER_WEBHOOK_SECRET").and_return("different")
        expect(valid_with(headers:)).to be false
      end

      it "is case-sensitive for secret values" do
        headers = { default_header => "MySecret" }

        allow(ENV).to receive(:[]).with("SUPER_WEBHOOK_SECRET").and_return("MySecret")
        expect(valid_with(headers:)).to be true

        allow(ENV).to receive(:[]).with("SUPER_WEBHOOK_SECRET").and_return("mysecret")
        expect(valid_with(headers:)).to be false

        allow(ENV).to receive(:[]).with("SUPER_WEBHOOK_SECRET").and_return("MYSECRET")
        expect(valid_with(headers:)).to be false
      end

      it "handles very long secrets" do
        long_secret = "a" * 1000
        headers = { default_header => long_secret }

        allow(ENV).to receive(:[]).with("SUPER_WEBHOOK_SECRET").and_return(long_secret)
        expect(valid_with(headers:)).to be true

        allow(ENV).to receive(:[]).with("SUPER_WEBHOOK_SECRET").and_return(long_secret + "x")
        expect(valid_with(headers:)).to be false
      end

      it "handles special characters in secrets" do
        special_secret = "secret!@#$%^&*()_+-=[]{}|;':\",./<>?"
        headers = { default_header => special_secret }

        allow(ENV).to receive(:[]).with("SUPER_WEBHOOK_SECRET").and_return(special_secret)
        expect(valid_with(headers:)).to be true
      end

      it "handles unicode characters in secrets" do
        # TODO
      end
    end

    context "security considerations" do
      let(:headers) { { default_header => secret } }

      it "uses secure comparison to prevent timing attacks" do
        # Test that we're using Rack::Utils.secure_compare
        expect(Rack::Utils).to receive(:secure_compare).with(secret, secret).and_return(true)
        expect(valid_with(headers:)).to be true
      end

      it "prevents timing attacks via whitespace manipulation" do
        # Ensure that if somehow whitespace gets through validation,
        # we still don't expose timing information by comparing directly
        headers_with_raw_secret = { default_header => secret }

        # Mock valid_header_value? to return true (simulating bypass)
        allow(described_class).to receive(:valid_header_value?).and_return(true)

        # Verify secure_compare is called with the raw secret, not stripped
        expect(Rack::Utils).to receive(:secure_compare).with(secret, secret).and_return(true)
        expect(valid_with(headers: headers_with_raw_secret)).to be true
      end

      it "handles exceptions gracefully" do
        # Mock an exception during validation
        allow(Rack::Utils).to receive(:secure_compare).and_raise(StandardError.new("test error"))
        expect(valid_with(headers:)).to be false
      end

      it "rejects headers with suspicious patterns" do
        # Test various suspicious header values
        suspicious_values = [
          "secret\x00injection",
          "secret\u0001control",
          "secret\x7fdelete"
        ]

        suspicious_values.each do |suspicious_value|
          bad_headers = { default_header => suspicious_value }
          expect(valid_with(headers: bad_headers)).to be false
        end
      end
    end
  end

  describe "DEFAULT_CONFIG" do
    it "has expected default values" do
      expect(described_class::DEFAULT_CONFIG).to include(
        header: "Authorization"
      )
    end

    it "is frozen" do
      expect(described_class::DEFAULT_CONFIG).to be_frozen
    end
  end

  describe "inheritance" do
    it "extends Base class" do
      expect(described_class.ancestors).to include(Hooks::Plugins::Auth::Base)
    end

    it "implements required valid? method" do
      expect(described_class).to respond_to(:valid?)
    end

    it "valid? method has expected signature" do
      method = described_class.method(:valid?)
      expect(method.parameters).to include([:keyreq, :payload])
      expect(method.parameters).to include([:keyreq, :headers])
      expect(method.parameters).to include([:keyreq, :config])
    end
  end

  describe "real-world scenarios" do
    context "Okta-style webhook validation" do
      let(:okta_secret) { "my-okta-webhook-secret-key" }
      let(:okta_config) do
        {
          auth: {
            header: "Authorization",
            secret_env_key: "OKTA_WEBHOOK_SECRET"
          }
        }
      end

      before do
        allow(ENV).to receive(:[]).with("OKTA_WEBHOOK_SECRET").and_return(okta_secret)
      end

      it "validates Okta-style webhook with Authorization header" do
        headers = { "Authorization" => okta_secret }
        result = described_class.valid?(
          payload: '{"eventType":"user.lifecycle.activate","eventId":"abc123"}',
          headers:,
          config: okta_config
        )
        expect(result).to be true
      end

      it "rejects invalid Okta-style webhook" do
        headers = { "Authorization" => "wrong-secret" }
        result = described_class.valid?(
          payload: '{"eventType":"user.lifecycle.activate","eventId":"abc123"}',
          headers:,
          config: okta_config
        )
        expect(result).to be false
      end
    end

    context "Generic API key validation" do
      let(:api_key) { "sk_live_12345abcdef" }
      let(:api_config) do
        {
          auth: {
            header: "X-API-Key",
            secret_env_key: "API_KEY_SECRET"
          }
        }
      end

      before do
        allow(ENV).to receive(:[]).with("API_KEY_SECRET").and_return(api_key)
      end

      it "validates API key in custom header" do
        headers = { "X-API-Key" => api_key }
        result = described_class.valid?(
          payload: '{"data":"value"}',
          headers:,
          config: api_config
        )
        expect(result).to be true
      end

      it "logs debug message on successful validation" do
        headers = { "X-API-Key" => api_key }
        allow(Hooks::Log.instance).to receive(:debug)

        described_class.valid?(
          payload: '{"data":"value"}',
          headers:,
          config: api_config
        )

        expect(Hooks::Log.instance).to have_received(:debug).with("Auth::SharedSecret validation successful for header 'X-API-Key'")
      end
    end

    context "Debug and warning logging coverage" do
      let(:test_secret) { "test-secret-123" }
      let(:test_config) do
        {
          auth: {
            header: "Authorization",
            secret_env_key: "TEST_SECRET"
          }
        }
      end

      before do
        allow(ENV).to receive(:[]).with("TEST_SECRET").and_return(test_secret)
        allow(Hooks::Log.instance).to receive(:debug)
        allow(Hooks::Log.instance).to receive(:warn)
        allow(Hooks::Log.instance).to receive(:error)
      end

      it "logs warning when signature mismatch occurs" do
        headers = { "Authorization" => "wrong-secret" }

        result = described_class.valid?(
          payload: '{"data":"value"}',
          headers:,
          config: test_config
        )

        expect(result).to be false
        expect(Hooks::Log.instance).to have_received(:warn).with("Auth::SharedSecret validation failed: Signature mismatch")
      end

      it "logs error and returns false on exception" do
        # Force an exception by mocking fetch_secret to raise
        allow(described_class).to receive(:fetch_secret).and_raise(StandardError, "Test error")

        result = described_class.valid?(
          payload: '{"data":"value"}',
          headers: { "Authorization" => "test" },
          config: test_config
        )

        expect(result).to be false
        expect(Hooks::Log.instance).to have_received(:error).with("Auth::SharedSecret validation failed: Test error")
      end
    end
  end
end
