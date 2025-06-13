# frozen_string_literal: true

require_relative "../../../../spec_helper"

# calls into spec_helper which sets up mocks around Time which is important to be aware of for HMAC tests

describe Hooks::Plugins::Auth::HMAC do
  let(:log) { instance_double(Logger).as_null_object }
  let(:secret) { "supersecret" }
  let(:payload) { '{"foo":"bar"}' }
  let(:default_header) { "X-Hub-Signature-256" }
  let(:default_algorithm) { "sha256" }
  let(:default_config) do
    {
      auth: {
        header: default_header,
        algorithm: default_algorithm,
        format: "algorithm=signature",
        secret_env_key: "HMAC_TEST_SECRET"
      }
    }
  end

  before(:each) do
    Hooks::Log.instance = log
    allow(ENV).to receive(:[]).with("HMAC_TEST_SECRET").and_return(secret)
  end

  def valid_with(args = {})
    args = { config: default_config }.merge(args)
    described_class.valid?(payload:, **args)
  end

  def create_signature(signing_payload, algorithm = "sha256")
    OpenSSL::HMAC.hexdigest(OpenSSL::Digest.new(algorithm), secret, signing_payload)
  end

  def create_algorithm_prefixed_signature(signing_payload = payload, algorithm = "sha256")
    "#{algorithm}=#{create_signature(signing_payload, algorithm)}"
  end

  def create_version_prefixed_signature(signing_payload, version = "v0")
    "#{version}=#{create_signature(signing_payload)}"
  end

  def create_timestamped_signature(timestamp, version = "v0")
    signing_payload = "#{version}:#{timestamp}:#{payload}"
    create_version_prefixed_signature(signing_payload, version)
  end

  describe ".valid?" do
    context "with algorithm-prefixed format" do
      let(:signature) { create_algorithm_prefixed_signature }
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
        # Test nil secret via environment variable
        allow(ENV).to receive(:[]).with("HMAC_TEST_SECRET").and_return(nil)
        expect(valid_with(headers:)).to be false

        # Test empty secret via environment variable
        allow(ENV).to receive(:[]).with("HMAC_TEST_SECRET").and_return("")
        expect(valid_with(headers:)).to be false
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
          auth: {
            header: header,
            algorithm: "sha256",
            format: "signature_only",
            secret_env_key: "HMAC_TEST_SECRET"
          }
        }
      end
      let(:signature) { create_signature(payload) }
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
      let(:signature) { create_timestamped_signature(timestamp) }
      let(:headers) { { header => signature, timestamp_header => timestamp } }
      let(:config) do
        {
          auth: {
            header: header,
            timestamp_header: timestamp_header,
            algorithm: "sha256",
            format: "version=signature",
            version_prefix: "v0",
            payload_template: "v0:{timestamp}:{body}",
            timestamp_tolerance: 300,
            secret_env_key: "HMAC_TEST_SECRET"
          }
        }
      end

      it "returns true for a valid versioned signature with valid timestamp" do
        expect(valid_with(headers:, config:)).to be true
      end

      it "returns false for an expired timestamp" do
        old_timestamp = (Time.now.to_i - 1000).to_s
        old_signature = create_timestamped_signature(old_timestamp)
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
          auth: {
            header:,
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
      let(:headers) { { "X-Signature" => create_algorithm_prefixed_signature } }
      let(:config) { { auth: { secret_env_key: "HMAC_TEST_SECRET" } } }

      it "uses defaults and validates correctly" do
        expect(valid_with(headers:, config:)).to be true
      end
    end

    context "with tampered payload" do
      let(:signature) { create_algorithm_prefixed_signature }
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

    context "security and edge cases" do
      let(:signature) { create_algorithm_prefixed_signature }
      let(:headers) { { default_header => signature } }

      it "returns false for empty signature header value" do
        empty_headers = { default_header => "" }
        expect(valid_with(headers: empty_headers)).to be false
      end

      it "returns false for whitespace-only signature" do
        whitespace_headers = { default_header => "   " }
        expect(valid_with(headers: whitespace_headers)).to be false
      end

      it "returns false for signature with only algorithm prefix" do
        incomplete_headers = { default_header => "sha256=" }
        expect(valid_with(headers: incomplete_headers)).to be false
      end

      it "returns false for malformed signature format" do
        malformed_headers = { default_header => "sha256" }
        expect(valid_with(headers: malformed_headers)).to be false
      end

      it "returns false for signature with wrong algorithm prefix" do
        wrong_algo_headers = { default_header => create_algorithm_prefixed_signature(payload, "sha1") }
        expect(valid_with(headers: wrong_algo_headers)).to be false
      end

      it "returns false for signature with extra characters" do
        tampered_headers = { default_header => signature + "extra" }
        expect(valid_with(headers: tampered_headers)).to be false
      end

      it "returns false for signature with leading/trailing whitespace" do
        whitespace_headers = { default_header => " #{signature} " }
        expect(valid_with(headers: whitespace_headers)).to be false
      end

      it "returns false for case-sensitive signature tampering" do
        case_tampered = signature.upcase
        case_headers = { default_header => case_tampered }
        expect(valid_with(headers: case_headers)).to be false
      end

      it "returns false for null byte injection in signature" do
        null_byte_headers = { default_header => signature + "\x00" }
        expect(valid_with(headers: null_byte_headers)).to be false
      end

      it "returns false for unicode normalization attacks" do
        # Using similar-looking unicode characters
        unicode_headers = { default_header => signature.gsub("a", "а") } # Cyrillic 'a'
        expect(valid_with(headers: unicode_headers)).to be false
      end

      it "returns false when secret contains null bytes" do
        null_secret = "secret\x00injection"
        allow(ENV).to receive(:[]).with("HMAC_TEST_SECRET").and_return(null_secret)
        expect(valid_with(headers:)).to be false
      end

      it "returns false when payload is modified with invisible characters" do
        invisible_payload = payload + "\u200b" # Zero-width space
        expect(valid_with(payload: invisible_payload, headers:)).to be false
      end

      it "handles very long signatures gracefully" do
        long_signature = "sha256=" + ("a" * 10000)
        long_headers = { default_header => long_signature }
        expect(valid_with(headers: long_headers)).to be false
      end

      it "handles very long payloads" do
        long_payload = "a" * 100000
        long_signature = create_algorithm_prefixed_signature(long_payload)
        long_headers = { default_header => long_signature }
        expect(valid_with(payload: long_payload, headers: long_headers)).to be true
      end

      it "returns false and logs for signature containing non-null control characters" do
        control_char = "\x01"
        headers_with_control = { default_header => signature + control_char }
        expect(log).to receive(:warn).with(/control characters/)
        expect(valid_with(headers: headers_with_control)).to be false
      end
    end

    context "format mismatch attacks" do
      let(:base_payload) { '{"data":"test"}' }

      it "fails when server expects algorithm-prefixed but receives hash-only" do
        # Server configured for algorithm-prefixed format
        server_config = {
          auth: {
            header: "X-Signature",
            algorithm: "sha256",
            format: "algorithm=signature"
          }
        }

        # Attacker sends hash-only format
        hash_only_sig = OpenSSL::HMAC.hexdigest(OpenSSL::Digest.new("sha256"), secret, base_payload)
        attacker_headers = { "X-Signature" => hash_only_sig }

        expect(valid_with(payload: base_payload, headers: attacker_headers, config: server_config)).to be false
      end

      it "fails when server expects hash-only but receives algorithm-prefixed" do
        # Server configured for hash-only format
        server_config = {
          auth: {
            header: "X-Signature",
            algorithm: "sha256",
            format: "signature_only"
          }
        }

        # Attacker sends algorithm-prefixed format
        algo_prefixed_sig = "sha256=" + OpenSSL::HMAC.hexdigest(OpenSSL::Digest.new("sha256"), secret, base_payload)
        attacker_headers = { "X-Signature" => algo_prefixed_sig }

        expect(valid_with(payload: base_payload, headers: attacker_headers, config: server_config)).to be false
      end

      it "fails when server expects version-prefixed but receives algorithm-prefixed" do
        # Server configured for version-prefixed format with timestamp
        timestamp = Time.now.to_i.to_s
        server_config = {
          auth: {
            header: "X-Signature",
            timestamp_header: "X-Timestamp",
            algorithm: "sha256",
            format: "version=signature",
            version_prefix: "v0",
            payload_template: "v0:{timestamp}:{body}",
            timestamp_tolerance: 300
          }
        }

        # Attacker sends algorithm-prefixed format (ignoring timestamp)
        algo_sig = "sha256=" + OpenSSL::HMAC.hexdigest(OpenSSL::Digest.new("sha256"), secret, base_payload)
        attacker_headers = {
          "X-Signature" => algo_sig,
          "X-Timestamp" => timestamp
        }

        expect(valid_with(payload: base_payload, headers: attacker_headers, config: server_config)).to be false
      end

      it "fails when server expects algorithm-prefixed but receives version-prefixed" do
        # Server configured for algorithm-prefixed format
        server_config = {
          auth: {
            header: "X-Signature",
            algorithm: "sha256",
            format: "algorithm=signature"
          }
        }
        # Attacker sends version-prefixed format
        timestamp = Time.now.to_i.to_s
        versioned_sig = "v0=" + OpenSSL::HMAC.hexdigest(OpenSSL::Digest.new("sha256"), secret, "v0:#{timestamp}:#{base_payload}")
        attacker_headers = {
          "X-Signature" => versioned_sig,
          "X-Timestamp" => timestamp
        }
        expect(valid_with(payload: base_payload, headers: attacker_headers, config: server_config)).to be false
      end

      it "fails when algorithm in config differs from signature prefix" do
        # Server configured for sha512
        server_config = {
          auth: {
            header: "X-Signature",
            algorithm: "sha512",
            format: "algorithm=signature"
          }
        }

        # Attacker sends sha256 signature
        sha256_sig = "sha256=" + OpenSSL::HMAC.hexdigest(OpenSSL::Digest.new("sha256"), secret, base_payload)
        attacker_headers = { "X-Signature" => sha256_sig }

        expect(valid_with(payload: base_payload, headers: attacker_headers, config: server_config)).to be false
      end

      it "fails when version prefix in config differs from signature" do
        timestamp = Time.now.to_i.to_s
        signing_payload = "v1:#{timestamp}:#{base_payload}"

        # Server configured for v0 prefix
        server_config = {
          auth: {
            header: "X-Signature",
            timestamp_header: "X-Timestamp",
            algorithm: "sha256",
            format: "version=signature",
            version_prefix: "v0",
            payload_template: "v0:{timestamp}:{body}",
            timestamp_tolerance: 300
          }
        }

        # Attacker sends v1 signature
        v1_sig = "v1=" + OpenSSL::HMAC.hexdigest(OpenSSL::Digest.new("sha256"), secret, signing_payload)
        attacker_headers = {
          "X-Signature" => v1_sig,
          "X-Timestamp" => timestamp
        }

        expect(valid_with(payload: base_payload, headers: attacker_headers, config: server_config)).to be false
      end
    end

    context "timestamp validation edge cases" do
      let(:header) { "X-Signature" }
      let(:timestamp_header) { "X-Timestamp" }
      let(:base_config) do
        {
          auth: {
            header:,
            timestamp_header:,
            algorithm: "sha256",
            format: "version=signature",
            version_prefix: "v0",
            payload_template: "v0:{timestamp}:{body}",
            timestamp_tolerance: 300,
            secret_env_key: "HMAC_TEST_SECRET"
          }
        }
      end

      context "Unix timestamp validation" do
        def test_invalid_timestamp(invalid_timestamp, description)
          signature = create_timestamped_signature(invalid_timestamp)
          headers = { header => signature, timestamp_header => invalid_timestamp }
          expect(valid_with(headers:, config: base_config)).to be false
        end

        it "returns false for negative timestamp" do
          test_invalid_timestamp("-1", "negative timestamp")
        end

        it "returns false for zero timestamp" do
          test_invalid_timestamp("0", "zero timestamp")
        end

        it "returns false for timestamp with decimal point" do
          test_invalid_timestamp("#{Time.now.to_i}.5", "decimal timestamp")
        end

        it "returns false for timestamp with leading zeros" do
          test_invalid_timestamp("00#{Time.now.to_i}", "padded timestamp")
        end

        it "returns false for timestamp with embedded null bytes" do
          test_invalid_timestamp("#{Time.now.to_i}\x00123", "null byte timestamp")
        end

        it "returns false for very large timestamp (year 2100+)" do
          test_invalid_timestamp("4000000000", "future timestamp")
        end
      end

      context "ISO 8601 UTC timestamp validation" do
        def test_iso_timestamp(iso_timestamp, should_be_valid)
          signature = create_timestamped_signature(iso_timestamp)
          headers = { header => signature, timestamp_header => iso_timestamp }
          expect(valid_with(headers:, config: base_config)).to be should_be_valid
        end

        it "returns true for valid ISO 8601 UTC timestamp with Z suffix" do
          iso_timestamp = Time.now.utc.strftime("%Y-%m-%dT%H:%M:%SZ")
          test_iso_timestamp(iso_timestamp, true)
        end

        it "returns true for valid ISO 8601 UTC timestamp with +00:00 suffix" do
          iso_timestamp = Time.now.utc.strftime("%Y-%m-%dT%H:%M:%S+00:00")
          test_iso_timestamp(iso_timestamp, true)
        end

        it "returns false for ISO 8601 timestamp without UTC indicator" do
          iso_timestamp = Time.now.utc.strftime("%Y-%m-%dT%H:%M:%S") # No Z or +00:00
          test_iso_timestamp(iso_timestamp, false)
        end

        it "returns false for ISO 8601 timestamp with non-UTC timezone" do
          iso_timestamp = Time.now.strftime("%Y-%m-%dT%H:%M:%S-05:00") # EST timezone
          test_iso_timestamp(iso_timestamp, false)
        end

        it "returns false for expired ISO 8601 timestamp" do
          expired_time = Time.now.utc - 1000 # 1000 seconds ago
          iso_timestamp = expired_time.strftime("%Y-%m-%dT%H:%M:%SZ")
          test_iso_timestamp(iso_timestamp, false)
        end

        it "returns false for malformed ISO 8601 timestamp" do
          malformed_iso = "2025-13-32T25:61:61Z" # Invalid date/time values
          test_iso_timestamp(malformed_iso, false)
        end
      end

      it "returns true when timestamp header name case differs due to normalization" do
        timestamp = Time.now.to_i.to_s
        signature = create_timestamped_signature(timestamp)

        # Use uppercase timestamp header name in the request headers
        headers = { header => signature, timestamp_header.upcase => timestamp }

        expect(valid_with(headers:, config: base_config)).to be true
      end
    end

    context "error handling and resilience" do
      it "returns false when OpenSSL raises an error" do
        allow(OpenSSL::HMAC).to receive(:hexdigest).and_raise(OpenSSL::OpenSSLError, "Invalid algorithm")

        signature = "sha256=fakesignature"
        headers = { default_header => signature }

        expect(valid_with(headers:)).to be false
      end

      it "returns false when Rack::Utils.secure_compare raises an error" do
        signature = "sha256=" + OpenSSL::HMAC.hexdigest(OpenSSL::Digest.new("sha256"), secret, payload)
        headers = { default_header => signature }

        allow(Rack::Utils).to receive(:secure_compare).and_raise(StandardError, "Comparison error")

        expect(valid_with(headers:)).to be false
      end

      it "returns false when Time.now raises an error" do
        config = {
          auth: {
            header: "X-Signature",
            timestamp_header: "X-Timestamp",
            algorithm: "sha256",
            format: "version=signature",
            version_prefix: "v0",
            payload_template: "v0:{timestamp}:{body}",
            timestamp_tolerance: 300
          }
        }

        timestamp = Time.now.to_i.to_s
        signing_payload = "v0:#{timestamp}:#{payload}"
        signature = "v0=" + OpenSSL::HMAC.hexdigest(OpenSSL::Digest.new("sha256"), secret, signing_payload)
        headers = { "X-Signature" => signature, "X-Timestamp" => timestamp }

        allow(Time).to receive(:now).and_raise(StandardError, "Time error")

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
      config = { auth: { algorithm: "sha512", format: "signature_only", header: "X-My-Sig" } }
      result = described_class.send(:build_config, config)
      expect(result[:algorithm]).to eq("sha512")
      expect(result[:format]).to eq("signature_only")
      expect(result[:header]).to eq("X-My-Sig")
    end
  end

  describe ".valid_timestamp?" do
    let(:config) do
      {
        timestamp_header: "X-Timestamp",
        timestamp_tolerance: 300
      }
    end

    it "returns false when timestamp header is nil in config" do
      no_header_config = { timestamp_tolerance: 300 }
      headers = { "x-timestamp" => Time.now.to_i.to_s }

      expect(described_class.send(:valid_timestamp?, headers, no_header_config)).to be false
    end

    it "returns false when timestamp value contains non-digits" do
      headers = { "x-timestamp" => "123abc" }

      expect(described_class.send(:valid_timestamp?, headers, config)).to be false
    end

    it "returns false when timestamp is empty string" do
      headers = { "x-timestamp" => "" }

      expect(described_class.send(:valid_timestamp?, headers, config)).to be false
    end

    it "returns true for valid Unix timestamp" do
      headers = { "x-timestamp" => Time.now.to_i.to_s }

      expect(described_class.send(:valid_timestamp?, headers, config)).to be true
    end

    it "returns true for valid ISO 8601 UTC timestamp" do
      headers = { "x-timestamp" => Time.now.utc.strftime("%Y-%m-%dT%H:%M:%SZ") }

      expect(described_class.send(:valid_timestamp?, headers, config)).to be true
    end
  end

  describe "debug and warning logging" do
    let(:secret) { "test-secret-123" }
    let(:config) do
      {
        auth: {
          header: "X-Signature",
          secret_env_key: "TEST_SECRET"
        }
      }
    end

    before do
      allow(ENV).to receive(:[]).with("TEST_SECRET").and_return(secret)
      allow(Hooks::Log.instance).to receive(:debug)
      allow(Hooks::Log.instance).to receive(:warn)
    end

    it "logs debug message on successful validation" do
      payload = '{"data": "test"}'
      signature = OpenSSL::HMAC.hexdigest(OpenSSL::Digest.new("sha256"), secret, payload)
      headers = { "X-Signature" => "sha256=#{signature}" }

      result = described_class.valid?(payload: payload, headers: headers, config: config)

      expect(result).to be true
      expect(Hooks::Log.instance).to have_received(:debug).with("Auth::HMAC validation successful for header 'X-Signature'")
    end

    it "logs warning message on signature mismatch" do
      payload = '{"data": "test"}'
      headers = { "X-Signature" => "sha256=wrong_signature" }

      result = described_class.valid?(payload: payload, headers: headers, config: config)

      expect(result).to be false
      expect(Hooks::Log.instance).to have_received(:warn).with("Auth::HMAC validation failed: Signature mismatch")
    end
  end
end
