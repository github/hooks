# frozen_string_literal: true

describe Hooks::Plugins::RequestValidator::HMAC do
  let(:secret) { "supersecret" }
  let(:payload) { '{"foo":"bar"}' }
  let(:default_header) { "X-Hub-Signature-256" }
  let(:default_algorithm) { "sha256" }
  let(:default_config) do
    {
      request_validator: {
        header: default_header,
        algorithm: default_algorithm,
        format: "algorithm=signature"
      }
    }
  end

  def valid_with(args = {})
    args = { config: default_config }.merge(args)
    described_class.valid?(payload:, secret:, **args)
  end

  describe ".valid?" do
    context "with algorithm-prefixed format" do
      let(:signature) { "sha256=" + OpenSSL::HMAC.hexdigest(OpenSSL::Digest.new("sha256"), secret, payload) }
      let(:headers) { { default_header => signature } }

      it "returns true for a valid signature" do
        expect(valid_with(headers:)).to be true
      end

      it "returns false for an invalid signature" do
        bad_headers = { default_header => "sha256=bad" }
        expect(valid_with(headers: bad_headers)).to be false
      end

      it "returns false if signature header is missing" do
        expect(valid_with(headers: {})).to be false
      end

      it "returns false if secret is nil or empty" do
        expect(valid_with(headers:, secret: nil)).to be false
        expect(valid_with(headers:, secret: "")).to be false
      end

      it "normalizes header names to lowercase" do
        upcase_headers = { default_header.upcase => signature }
        expect(valid_with(headers: upcase_headers)).to be true
      end
    end

    context "with hash-only format" do
      let(:header) { "X-Signature-Hash" }
      let(:config) do
        {
          request_validator: {
            header: header,
            algorithm: "sha256",
            format: "signature_only"
          }
        }
      end
      let(:signature) { OpenSSL::HMAC.hexdigest(OpenSSL::Digest.new("sha256"), secret, payload) }
      let(:headers) { { header => signature } }

      it "returns true for a valid hash-only signature" do
        expect(valid_with(headers:, config:)).to be true
      end

      it "returns false for an invalid hash-only signature" do
        bad_headers = { header => "bad" }
        expect(valid_with(headers: bad_headers, config:)).to be false
      end
    end

    context "with version-prefixed format and timestamp" do
      let(:header) { "X-Signature-Versioned" }
      let(:timestamp_header) { "X-Request-Timestamp" }
      let(:timestamp) { Time.now.to_i.to_s }
      let(:payload_template) { "v0:{timestamp}:{body}" }
      let(:signing_payload) { "v0:#{timestamp}:#{payload}" }
      let(:signature) { "v0=" + OpenSSL::HMAC.hexdigest(OpenSSL::Digest.new("sha256"), secret, signing_payload) }
      let(:headers) { { header => signature, timestamp_header => timestamp } }
      let(:config) do
        {
          request_validator: {
            header: header,
            timestamp_header: timestamp_header,
            algorithm: "sha256",
            format: "version=signature",
            version_prefix: "v0",
            payload_template: payload_template,
            timestamp_tolerance: 300
          }
        }
      end

      it "returns true for a valid versioned signature with valid timestamp" do
        expect(valid_with(headers:, config:)).to be true
      end

      it "returns false for an expired timestamp" do
        old_timestamp = (Time.now.to_i - 1000).to_s
        old_signing_payload = "v0:#{old_timestamp}:#{payload}"
        old_signature = "v0=" + OpenSSL::HMAC.hexdigest(OpenSSL::Digest.new("sha256"), secret, old_signing_payload)
        bad_headers = { header => old_signature, timestamp_header => old_timestamp }
        expect(valid_with(headers: bad_headers, config:)).to be false
      end

      it "returns false if timestamp header is missing" do
        bad_headers = { header => signature }
        expect(valid_with(headers: bad_headers, config:)).to be false
      end

      it "returns false if timestamp is not an integer string" do
        bad_headers = { header => signature, timestamp_header => "notanumber" }
        expect(valid_with(headers: bad_headers, config:)).to be false
      end
    end

    context "with unsupported algorithm" do
      let(:header) { "X-Unsupported-Alg" }
      let(:config) do
        {
          request_validator: {
            header: header,
            algorithm: "md5",
            format: "algorithm=signature"
          }
        }
      end
      let(:signature) { "sha256=" + OpenSSL::HMAC.hexdigest(OpenSSL::Digest.new("sha256"), secret, payload) }
      let(:headers) { { header => signature } }

      it "returns false for unsupported algorithm" do
        expect(valid_with(headers:, config:)).to be false
      end
    end

    context "with missing config values" do
      let(:headers) { { "X-Signature" => "sha256=" + OpenSSL::HMAC.hexdigest(OpenSSL::Digest.new("sha256"), secret, payload) } }
      let(:config) { {} }

      it "uses defaults and validates correctly" do
        expect(valid_with(headers:, config:)).to be true
      end
    end

    context "with tampered payload" do
      let(:signature) { "sha256=" + OpenSSL::HMAC.hexdigest(OpenSSL::Digest.new("sha256"), secret, payload) }
      let(:headers) { { default_header => signature } }
      let(:tampered_payload) { '{"foo":"evil"}' }

      it "returns false if payload does not match signature" do
        expect(valid_with(payload: tampered_payload, headers:)).to be false
      end
    end

    context "with nil headers" do
      let(:headers) { nil }
      it "returns false" do
        expect(valid_with(headers:)).to be false
      end
    end

    context "with invalid config structure" do
      let(:headers) { { default_header => "sha256=bad" } }
      let(:config) { { not_validator: true } }
      it "returns false" do
        expect(valid_with(headers:, config:)).to be false
      end
    end
  end

  describe ".build_signing_payload" do
    let(:headers) { { "x-timestamp" => "12345" } }
    it "substitutes variables in template" do
      template = "v0:{timestamp}:{body}"
      config = { version_prefix: "v0", timestamp_header: "x-timestamp", payload_template: template }
      result = described_class.send(:build_signing_payload, payload:, headers:, config:)
      expect(result).to eq("v0:12345:{\"foo\":\"bar\"}")
    end
    it "returns payload if no template" do
      config = {}
      result = described_class.send(:build_signing_payload, payload:, headers:, config:)
      expect(result).to eq(payload)
    end
  end

  describe ".format_signature" do
    it "formats algorithm-prefixed" do
      config = { algorithm: "sha256", format: "algorithm=signature" }
      expect(described_class.send(:format_signature, "abc123", config)).to eq("sha256=abc123")
    end
    it "formats hash-only" do
      config = { format: "signature_only" }
      expect(described_class.send(:format_signature, "abc123", config)).to eq("abc123")
    end
    it "formats version-prefixed" do
      config = { version_prefix: "v0", format: "version=signature" }
      expect(described_class.send(:format_signature, "abc123", config)).to eq("v0=abc123")
    end
    it "defaults to algorithm-prefixed" do
      config = { algorithm: "sha256", format: "unknown" }
      expect(described_class.send(:format_signature, "abc123", config)).to eq("sha256=abc123")
    end
  end

  describe ".normalize_headers" do
    it "returns empty hash for nil headers" do
      expect(described_class.send(:normalize_headers, nil)).to eq({})
    end
    it "downcases header keys" do
      headers = { "X-FOO" => "bar" }
      expect(described_class.send(:normalize_headers, headers)).to eq({ "x-foo" => "bar" })
    end
  end

  describe ".build_config" do
    it "applies defaults when config is missing" do
      expect(described_class.send(:build_config, {})).to include(:algorithm, :format, :timestamp_tolerance, :version_prefix)
    end
    it "overrides defaults with provided config" do
      config = { request_validator: { algorithm: "sha512", format: "signature_only", header: "X-My-Sig" } }
      result = described_class.send(:build_config, config)
      expect(result[:algorithm]).to eq("sha512")
      expect(result[:format]).to eq("signature_only")
      expect(result[:header]).to eq("X-My-Sig")
    end
  end
end
