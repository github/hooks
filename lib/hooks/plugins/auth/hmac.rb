# frozen_string_literal: true

require "openssl"
require "time"
require_relative "base"

module Hooks
  module Plugins
    module Auth
      # Generic HMAC signature validator for webhooks
      #
      # This validator supports multiple webhook providers with different signature formats.
      # It provides flexible configuration options to handle various HMAC-based authentication schemes.
      #
      # @example Basic configuration with algorithm prefix
      #   auth:
      #     type: HMAC
      #     secret_env_key: WEBHOOK_SECRET
      #     header: X-Hub-Signature-256
      #     algorithm: sha256
      #     format: "algorithm=signature"
      #
      # @example Configuration with timestamp validation
      #   auth:
      #     type: HMAC
      #     secret_env_key: WEBHOOK_SECRET
      #     header: X-Signature
      #     timestamp_header: X-Request-Timestamp
      #     timestamp_tolerance: 300  # 5 minutes
      #     algorithm: sha256
      #     format: "version=signature"
      #     version_prefix: "v0"
      #     payload_template: "{version}:{timestamp}:{body}"
      class HMAC < Base
        # Default configuration values for HMAC validation
        #
        # @return [Hash<Symbol, String|Integer>] Default configuration settings
        # @note These values provide sensible defaults for most webhook implementations
        DEFAULT_CONFIG = {
          algorithm: "sha256",
          format: "algorithm=signature",  # Format: algorithm=hash
          timestamp_tolerance: 300,       # 5 minutes tolerance for timestamp validation
          version_prefix: "v0"           # Default version prefix for versioned signatures
        }.freeze

        # Mapping of signature format strings to internal format symbols
        #
        # @return [Hash<String, Symbol>] Format string to symbol mapping
        # @note Supports three common webhook signature formats:
        #   - algorithm=signature: "sha256=abc123..." (GitHub, GitLab style)
        #   - signature_only: "abc123..." (Shopify style)
        #   - version=signature: "v0=abc123..." (Slack style)
        FORMATS = {
          "algorithm=signature" => :algorithm_prefixed,  # "sha256=abc123..."
          "signature_only" => :hash_only,                # "abc123..."
          "version=signature" => :version_prefixed       # "v0=abc123..."
        }.freeze

        # Validate HMAC signature from webhook requests
        #
        # Performs comprehensive HMAC signature validation with support for multiple
        # signature formats and optional timestamp validation. Uses secure comparison
        # to prevent timing attacks.
        #
        # @param payload [String] Raw request body to validate
        # @param headers [Hash<String, String>] HTTP headers from the request
        # @param config [Hash] Endpoint configuration containing validator settings
        # @option config [Hash] :auth Validator-specific configuration
        # @option config [String] :header ('X-Signature') Header containing the signature
        # @option config [String] :timestamp_header Header containing timestamp (optional)
        # @option config [Integer] :timestamp_tolerance (300) Timestamp tolerance in seconds
        # @option config [String] :algorithm ('sha256') HMAC algorithm to use
        # @option config [String] :format ('algorithm=signature') Signature format
        # @option config [String] :version_prefix ('v0') Version prefix for versioned signatures
        # @option config [String] :payload_template Template for payload construction
        # @return [Boolean] true if signature is valid, false otherwise
        # @raise [StandardError] Rescued internally, returns false on any error
        # @note This method is designed to be safe and will never raise exceptions
        # @note Uses Rack::Utils.secure_compare to prevent timing attacks
        # @example Basic validation
        #   HMAC.valid?(
        #     payload: request_body,
        #     headers: request.headers,
        #     config: { auth: { header: 'X-Signature' } }
        #   )
        def self.valid?(payload:, headers:, config:)
          # fetch the required secret from environment variable as specified in the config
          secret = fetch_secret(config)

          validator_config = build_config(config)

          # Security: Check raw headers BEFORE normalization to detect tampering
          return false unless headers.respond_to?(:each)

          signature_header = validator_config[:header]

          # Find the signature header with case-insensitive matching but preserve original value
          raw_signature = nil
          headers.each do |key, value|
            if key.to_s.downcase == signature_header.downcase
              raw_signature = value.to_s
              break
            end
          end

          return false if raw_signature.nil? || raw_signature.empty?

          # Security: Reject signatures with leading/trailing whitespace
          return false if raw_signature != raw_signature.strip

          # Security: Reject signatures containing null bytes or other control characters
          return false if raw_signature.match?(/[\u0000-\u001f\u007f-\u009f]/)

          # Now we can safely normalize headers for the rest of the validation
          normalized_headers = normalize_headers(headers)
          provided_signature = normalized_headers[signature_header.downcase]

          # Validate timestamp if required (for services that include timestamp validation)
          if validator_config[:timestamp_header]
            unless valid_timestamp?(normalized_headers, validator_config)
              log.warn("Auth::HMAC validation failed: Invalid timestamp")
              return false
            end
          end

          # Compute expected signature
          computed_signature = compute_signature(
            payload:,
            headers: normalized_headers,
            secret:,
            config: validator_config
          )

          # Use secure comparison to prevent timing attacks
          Rack::Utils.secure_compare(computed_signature, provided_signature)
        rescue StandardError => e
          log.error("Auth::HMAC validation failed: #{e.message}")
          false
        end

        private

        # Build final configuration by merging defaults with provided config
        #
        # Combines default configuration values with user-provided settings,
        # ensuring all required configuration keys are present with sensible defaults.
        #
        # @param config [Hash] Raw endpoint configuration
        # @return [Hash<Symbol, Object>] Merged configuration with defaults applied
        # @note Missing configuration values are filled with DEFAULT_CONFIG values
        # @api private
        def self.build_config(config)
          validator_config = config.dig(:auth) || {}

          algorithm = validator_config[:algorithm] || DEFAULT_CONFIG[:algorithm]
          tolerance = validator_config[:timestamp_tolerance] || DEFAULT_CONFIG[:timestamp_tolerance]

          DEFAULT_CONFIG.merge({
            header: validator_config[:header] || "X-Signature",
            timestamp_header: validator_config[:timestamp_header],
            timestamp_tolerance: tolerance,
            algorithm: algorithm,
            format: validator_config[:format] || DEFAULT_CONFIG[:format],
            version_prefix: validator_config[:version_prefix] || DEFAULT_CONFIG[:version_prefix],
            payload_template: validator_config[:payload_template]
          })
        end

        # Normalize headers using the Utils::Normalize class
        #
        # Converts header hash to normalized format with lowercase keys for
        # case-insensitive header matching.
        #
        # @param headers [Hash<String, String>] Raw HTTP headers
        # @return [Hash<String, String>] Normalized headers with lowercase keys
        # @note Returns empty hash if headers is nil
        # @api private
        def self.normalize_headers(headers)
          Utils::Normalize.headers(headers) || {}
        end

        # Validate timestamp if timestamp validation is configured
        #
        # Checks if the provided timestamp is within the configured tolerance
        # of the current time. This prevents replay attacks using old requests.
        # Supports both ISO 8601 UTC timestamps and Unix timestamps.
        #
        # @param headers [Hash<String, String>] Normalized HTTP headers
        # @param config [Hash<Symbol, Object>] Validator configuration
        # @return [Boolean] true if timestamp is valid or not required, false otherwise
        # @note Returns false if timestamp header is missing when required
        # @note Tolerance is applied as absolute difference (past or future)
        # @note Tries ISO 8601 UTC format first, then falls back to Unix timestamp
        # @api private
        def self.valid_timestamp?(headers, config)
          timestamp_header = config[:timestamp_header]
          tolerance = config[:timestamp_tolerance] || 300
          return false unless timestamp_header

          timestamp_value = headers[timestamp_header.downcase]
          return false unless timestamp_value
          return false if timestamp_value.strip.empty?

          parsed_timestamp = parse_timestamp(timestamp_value.strip)
          return false unless parsed_timestamp.is_a?(Integer)

          now = Time.now.utc.to_i
          (now - parsed_timestamp).abs <= tolerance
        end

        # Parse timestamp value supporting both ISO 8601 UTC and Unix formats
        #
        # @param timestamp_value [String] The timestamp string to parse
        # @return [Integer, nil] Epoch seconds if parsing succeeds, nil otherwise
        # @note Security: Strict validation prevents various injection attacks
        # @api private
        def self.parse_timestamp(timestamp_value)
          # Reject if contains any control characters, whitespace, or null bytes
          if timestamp_value =~ /[\u0000-\u001F\u007F-\u009F]/
            log.warn("Auth::HMAC validation failed: Timestamp contains invalid characters")
            return nil
          end
          if timestamp_value != timestamp_value.strip
            log.warn("Auth::HMAC validation failed: Timestamp contains leading/trailing whitespace")
            return nil
          end
          ts = parse_iso8601_timestamp(timestamp_value)
          return ts if ts
          ts = parse_unix_timestamp(timestamp_value)
          return ts if ts

          # If neither format matches, return nil
          log.warn("Auth::HMAC validation failed: Timestamp (#{timestamp_value}) is not valid ISO 8601 UTC or Unix format")
          return nil
        end

        # Check if timestamp string looks like ISO 8601 UTC format (must have UTC indicator)
        #
        # @param timestamp_value [String] The timestamp string to check
        # @return [Boolean] true if it appears to be ISO 8601 format (with or without UTC indicator)
        # @api private
        def self.iso8601_timestamp?(timestamp_value)
          !!(timestamp_value =~ /\A\d{4}-\d{2}-\d{2}[T ]\d{2}:\d{2}:\d{2}(?:\.\d+)?(Z|\+00:00|\+0000)?\z/)
        end

        # Parse ISO 8601 UTC timestamp string (must have UTC indicator)
        #
        # @param timestamp_value [String] ISO 8601 timestamp string
        # @return [Integer, nil] Epoch seconds if parsing succeeds, nil otherwise
        # @note Only accepts UTC timestamps (ending with 'Z', '+00:00', '+0000')
        # @api private
        def self.parse_iso8601_timestamp(timestamp_value)
          if timestamp_value =~ /\A(\d{4}-\d{2}-\d{2}) (\d{2}:\d{2}:\d{2}(?:\.\d+)?)(?: )\+0000\z/
            timestamp_value = "#{$1}T#{$2}+00:00"
          end
          return nil unless iso8601_timestamp?(timestamp_value)
          t = Time.parse(timestamp_value) rescue nil
          return nil unless t
          (t.utc? || t.utc_offset == 0) ? t.to_i : nil
        end

        # Parse Unix timestamp string (must be positive integer, no leading zeros except for "0")
        #
        # @param timestamp_value [String] Unix timestamp string
        # @return [Integer, nil] Epoch seconds if parsing succeeds, nil otherwise
        # @note Only accepts positive integer values, no leading zeros except for "0"
        # @api private
        def self.parse_unix_timestamp(timestamp_value)
          return nil unless unix_timestamp?(timestamp_value)
          ts = timestamp_value.to_i
          return nil if ts <= 0
          ts
        end

        # Check if timestamp string looks like Unix timestamp format (no leading zeros except "0")
        #
        # @param timestamp_value [String] The timestamp string to check
        # @return [Boolean] true if it appears to be Unix timestamp format
        # @api private
        def self.unix_timestamp?(timestamp_value)
          return true if timestamp_value == "0"
          !!(timestamp_value =~ /\A[1-9]\d*\z/)
        end

        # Compute HMAC signature based on configuration requirements
        #
        # Generates the expected HMAC signature for the given payload using the
        # specified algorithm and formatting rules.
        #
        # @param payload [String] Raw request body
        # @param headers [Hash<String, String>] Normalized HTTP headers
        # @param secret [String] Secret key for HMAC computation
        # @param config [Hash<Symbol, Object>] Validator configuration
        # @return [String] Formatted HMAC signature
        # @note The returned signature format depends on the configured format style
        # @api private
        def self.compute_signature(payload:, headers:, secret:, config:)
          # Determine what to sign based on payload template
          signing_payload = build_signing_payload(
            payload:,
            headers:,
            config:
          )

          # Compute HMAC hash
          algorithm = config[:algorithm]
          computed_hash = OpenSSL::HMAC.hexdigest(
            OpenSSL::Digest.new(algorithm),
            secret,
            signing_payload
          )

          # Format according to provider requirements
          format_signature(computed_hash, config)
        end

        # Build the payload string to sign (handles templated payload requirements)
        #
        # Constructs the signing payload based on configuration. Some webhook services
        # require specific payload formats that include metadata like timestamps.
        #
        # @param payload [String] Raw request body
        # @param headers [Hash<String, String>] Normalized HTTP headers
        # @param config [Hash<Symbol, Object>] Validator configuration
        # @return [String] Payload string ready for HMAC computation
        # @note When payload_template is provided, it supports variable substitution:
        #   - {version}: Replaced with version_prefix
        #   - {timestamp}: Replaced with timestamp from headers
        #   - {body}: Replaced with the raw payload
        # @example Template usage
        #   template: "{version}:{timestamp}:{body}"
        #   result: "v0:1609459200:{\"event\":\"push\"}"
        # @api private
        def self.build_signing_payload(payload:, headers:, config:)
          template = config[:payload_template]

          if template
            # Templated payload format (e.g., "v0:timestamp:body" for timestamp-based validation)
            timestamp = headers[config[:timestamp_header].downcase]
            template
              .gsub("{version}", config[:version_prefix])
              .gsub("{timestamp}", timestamp.to_s)
              .gsub("{body}", payload)
          else
            # Standard: just the payload
            payload
          end
        end

        # Format the computed signature based on configuration requirements
        #
        # Applies the appropriate formatting to the computed HMAC hash based on
        # the configured signature format style.
        #
        # @param hash [String] Raw HMAC hash (hexadecimal string)
        # @param config [Hash<Symbol, Object>] Validator configuration
        # @return [String] Formatted signature string
        # @note Supported formats:
        #   - :algorithm_prefixed: "sha256=abc123..." (GitHub style)
        #   - :hash_only: "abc123..." (Shopify style)
        #   - :version_prefixed: "v0=abc123..." (Slack style)
        # @note Defaults to algorithm-prefixed format for unknown format styles
        # @api private
        def self.format_signature(hash, config)
          format_style = FORMATS[config[:format]]

          case format_style
          when :algorithm_prefixed
            # Algorithm-prefixed format: "sha256=abc123..." (used by GitHub, GitLab, etc.)
            "#{config[:algorithm]}=#{hash}"
          when :hash_only
            # Hash-only format: "abc123..." (used by Shopify, etc.)
            hash
          when :version_prefixed
            # Version-prefixed format: "v0=abc123..." (used by Slack, etc.)
            "#{config[:version_prefix]}=#{hash}"
          else
            # Default to algorithm-prefixed format
            "#{config[:algorithm]}=#{hash}"
          end
        end
      end
    end
  end
end
