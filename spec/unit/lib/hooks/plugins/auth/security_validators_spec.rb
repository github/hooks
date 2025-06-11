# frozen_string_literal: true

require_relative "../../../../spec_helper"

describe "Security Tests for Authentication Validators" do
  let(:secret) { "test-secret-key" }
  let(:payload) { '{"test": "data"}' }

  describe Hooks::Plugins::Auth::HMAC do
    describe "timing attack resistance" do
      it "uses secure comparison for signature validation" do
        # Mock Rack::Utils to verify secure_compare is called
        allow(Rack::Utils).to receive(:secure_compare).and_return(false)

        config = { auth: { header: "X-Signature", algorithm: "sha256" } }
        headers = { "X-Signature" => "sha256=invalid" }

        described_class.valid?(payload:, headers:, secret:, config:)

        expect(Rack::Utils).to have_received(:secure_compare)
      end
    end

    describe "input sanitization" do
      let(:config) { { auth: { header: "X-Signature", algorithm: "sha256" } } }

      it "rejects signatures with control characters" do
        malicious_signature = "sha256=abcd\x00efgh"
        headers = { "X-Signature" => malicious_signature }

        result = described_class.valid?(payload:, headers:, secret:, config:)
        expect(result).to be false
      end

      it "rejects signatures with leading whitespace" do
        valid_sig = "sha256=" + OpenSSL::HMAC.hexdigest(OpenSSL::Digest.new("sha256"), secret, payload)
        malicious_signature = " #{valid_sig}"
        headers = { "X-Signature" => malicious_signature }

        result = described_class.valid?(payload:, headers:, secret:, config:)
        expect(result).to be false
      end

      it "rejects signatures with trailing whitespace" do
        valid_sig = "sha256=" + OpenSSL::HMAC.hexdigest(OpenSSL::Digest.new("sha256"), secret, payload)
        malicious_signature = "#{valid_sig} "
        headers = { "X-Signature" => malicious_signature }

        result = described_class.valid?(payload:, headers:, secret:, config:)
        expect(result).to be false
      end

      it "rejects empty signatures" do
        headers = { "X-Signature" => "" }

        result = described_class.valid?(payload:, headers:, secret:, config:)
        expect(result).to be false
      end

      it "rejects nil signatures" do
        headers = { "X-Signature" => nil }

        result = described_class.valid?(payload:, headers:, secret:, config:)
        expect(result).to be false
      end
    end

    describe "timestamp validation security" do
      let(:config) do
        {
          auth: {
            header: "X-Signature",
            algorithm: "sha256",
            timestamp_header: "X-Timestamp",
            timestamp_tolerance: 300
          }
        }
      end

      it "rejects non-numeric timestamps" do
        headers = {
          "X-Signature" => "sha256=test",
          "X-Timestamp" => "not-a-number"
        }

        result = described_class.valid?(payload:, headers:, secret:, config:)
        expect(result).to be false
      end

      it "rejects negative timestamps" do
        headers = {
          "X-Signature" => "sha256=test",
          "X-Timestamp" => "-123"
        }

        result = described_class.valid?(payload:, headers:, secret:, config:)
        expect(result).to be false
      end

      it "rejects timestamps with leading zeros" do
        headers = {
          "X-Signature" => "sha256=test",
          "X-Timestamp" => "01234567890" # Has leading zero
        }

        result = described_class.valid?(payload:, headers:, secret:, config:)
        expect(result).to be false
      end

      it "allows timestamp zero as edge case" do
        # This tests the special case where "0" is allowed but 0 is rejected
        headers = {
          "X-Signature" => "sha256=test",
          "X-Timestamp" => "0"
        }

        # Should reject because timestamp > 0 check fails, not because of pattern
        result = described_class.valid?(payload:, headers:, secret:, config:)
        expect(result).to be false
      end
    end

    describe "header injection protection" do
      let(:config) { { auth: { header: "X-Signature", algorithm: "sha256" } } }

      it "handles headers with injection attempts" do
        # Try to inject additional headers
        malicious_headers = {
          "X-Signature" => "sha256=test\r\nX-Injected: malicious",
          "Content-Type" => "application/json"
        }

        result = described_class.valid?(payload:, headers: malicious_headers, secret:, config:)
        expect(result).to be false
      end
    end
  end

  describe Hooks::Plugins::Auth::SharedSecret do
    describe "timing attack resistance" do
      it "uses secure comparison for secret validation" do
        # Mock Rack::Utils to verify secure_compare is called
        allow(Rack::Utils).to receive(:secure_compare).and_return(false)

        config = { auth: { header: "Authorization" } }
        headers = { "Authorization" => "wrong-secret" }

        described_class.valid?(payload:, headers:, secret:, config:)

        expect(Rack::Utils).to have_received(:secure_compare)
      end
    end

    describe "input sanitization" do
      let(:config) { { auth: { header: "Authorization" } } }

      it "rejects secrets with control characters" do
        malicious_secret = "secret\x00data"
        headers = { "Authorization" => malicious_secret }

        result = described_class.valid?(payload:, headers:, secret:, config:)
        expect(result).to be false
      end

      it "rejects secrets with leading whitespace" do
        malicious_secret = " #{secret}"
        headers = { "Authorization" => malicious_secret }

        result = described_class.valid?(payload:, headers:, secret:, config:)
        expect(result).to be false
      end

      it "rejects secrets with trailing whitespace" do
        malicious_secret = "#{secret} "
        headers = { "Authorization" => malicious_secret }

        result = described_class.valid?(payload:, headers:, secret:, config:)
        expect(result).to be false
      end

      it "rejects empty secrets" do
        headers = { "Authorization" => "" }

        result = described_class.valid?(payload:, headers:, secret:, config:)
        expect(result).to be false
      end

      it "rejects nil secrets" do
        headers = { "Authorization" => nil }

        result = described_class.valid?(payload:, headers:, secret:, config:)
        expect(result).to be false
      end
    end

    describe "header injection protection" do
      let(:config) { { auth: { header: "Authorization" } } }

      it "handles headers with injection attempts" do
        # Try to inject additional headers
        malicious_headers = {
          "Authorization" => "secret\r\nX-Injected: malicious",
          "Content-Type" => "application/json"
        }

        result = described_class.valid?(payload:, headers: malicious_headers, secret:, config:)
        expect(result).to be false
      end
    end
  end

  describe "Cross-validator security consistency" do
    let(:hmac_config) { { auth: { header: "X-Signature", algorithm: "sha256" } } }
    let(:shared_secret_config) { { auth: { header: "Authorization" } } }

    it "both validators reject nil secrets consistently" do
      headers = { "X-Signature" => "test", "Authorization" => "test" }

      hmac_result = Hooks::Plugins::Auth::HMAC.valid?(payload:, headers:, secret: nil, config: hmac_config)
      shared_secret_result = Hooks::Plugins::Auth::SharedSecret.valid?(payload:, headers:, secret: nil, config: shared_secret_config)

      expect(hmac_result).to be false
      expect(shared_secret_result).to be false
    end

    it "both validators reject empty secrets consistently" do
      headers = { "X-Signature" => "test", "Authorization" => "test" }

      hmac_result = Hooks::Plugins::Auth::HMAC.valid?(payload:, headers:, secret: "", config: hmac_config)
      shared_secret_result = Hooks::Plugins::Auth::SharedSecret.valid?(payload:, headers:, secret: "", config: shared_secret_config)

      expect(hmac_result).to be false
      expect(shared_secret_result).to be false
    end

    it "both validators handle non-hash headers consistently" do
      non_hash_headers = "not a hash"

      hmac_result = Hooks::Plugins::Auth::HMAC.valid?(payload:, headers: non_hash_headers, secret:, config: hmac_config)
      shared_secret_result = Hooks::Plugins::Auth::SharedSecret.valid?(payload:, headers: non_hash_headers, secret:, config: shared_secret_config)

      expect(hmac_result).to be false
      expect(shared_secret_result).to be false
    end
  end
end
