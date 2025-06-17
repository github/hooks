# frozen_string_literal: true

require "openssl"
require "time"
require_relative "base"
require_relative "timestamp_validator"

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
      #
      # @example Configuration for Tailscale-style structured headers
      #   auth:
      #     type: HMAC
      #     secret_env_key: WEBHOOK_SECRET
      #     header: Tailscale-Webhook-Signature
      #     algorithm: sha256
      #     format: "signature_only"
      #     header_format: "structured"
      #     signature_key: "v1"
      #     timestamp_key: "t"
      #     payload_template: "{timestamp}.{body}"
      #     timestamp_tolerance: 300  # 5 minutes
      class HMAC < Base
        # Security constants
        MAX_SIGNATURE_LENGTH = ENV.fetch("HOOKS_MAX_SIGNATURE_LENGTH", 1024).to_i # Prevent DoS attacks via large signatures

        # Default configuration values for HMAC validation
        #
        # @return [Hash<Symbol, String|Integer>] Default configuration settings
        # @note These values provide sensible defaults for most webhook implementations
        DEFAULT_CONFIG = {
          algorithm: "sha256",
          format: "algorithm=signature",  # Format: algorithm=hash
          header: "X-Signature",         # Default header containing the signature
          timestamp_tolerance: 300,       # 5 minutes tolerance for timestamp validation
          version_prefix: "v0",          # Default version prefix for versioned signatures
          header_format: "simple"        # Header format: "simple" or "structured"
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
        # @option config [String] :header_format ('simple') Header format: 'simple' or 'structured'
        # @option config [String] :signature_key ('v1') Key for signature in structured headers
        # @option config [String] :timestamp_key ('t') Key for timestamp in structured headers
        # @option config [String] :structured_header_separator (',') Separator for structured headers
        # @option config [String] :key_value_separator ('=') Separator for key-value pairs in structured headers
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

          # Security: Check raw headers and payload BEFORE processing
          return false unless valid_headers?(headers)
          return false unless valid_payload_size?(payload)

          signature_header = validator_config[:header]

          # Find the signature header with case-insensitive matching
          raw_signature = find_header_value(headers, signature_header)

          if raw_signature.nil? || raw_signature.empty?
            log.warn("Auth::HMAC validation failed: Missing or empty signature header '#{signature_header}'")
            return false
          end

          # Validate signature format using shared validation but with HMAC-specific length limit
          return false unless validate_signature_format(raw_signature)

          # Now we can safely normalize headers for the rest of the validation
          normalized_headers = normalize_headers(headers)

          # Handle structured headers (e.g., Tailscale format: "t=123,v1=abc")
          if validator_config[:header_format] == "structured"
            parsed_signature_data = parse_structured_header(raw_signature, validator_config)
            if parsed_signature_data.nil?
              log.warn("Auth::HMAC validation failed: Could not parse structured signature header")
              return false
            end

            provided_signature = parsed_signature_data[:signature]

            # For structured headers, timestamp comes from the signature header itself
            if parsed_signature_data[:timestamp]
              normalized_headers = normalized_headers.merge(
                "extracted_timestamp" => parsed_signature_data[:timestamp]
              )
              # Override timestamp_header to use our extracted timestamp
              validator_config = validator_config.merge(timestamp_header: "extracted_timestamp")
            end
          else
            provided_signature = normalized_headers[signature_header.downcase]
          end

          # Validate timestamp if required (for services that include timestamp validation)
          # It should be noted that not all HMAC implementations require timestamp validation,
          # so this is optional based on configuration.
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
          result = Rack::Utils.secure_compare(computed_signature, provided_signature)
          if result
            log.debug("Auth::HMAC validation successful for header '#{signature_header}'")
          else
            log.warn("Auth::HMAC validation failed: Signature mismatch")
          end
          result
        rescue StandardError => e
          log.error("Auth::HMAC validation failed: #{e.message}")
          false
        end

        private

        # Validate signature format for HMAC (uses HMAC-specific length limit)
        #
        # @param signature [String] Raw signature to validate
        # @return [Boolean] true if signature is valid
        # @api private
        def self.validate_signature_format(signature)
          # Check signature length with HMAC-specific limit
          if signature.length > MAX_SIGNATURE_LENGTH
            log.warn("Auth::HMAC validation failed: Signature length exceeds maximum limit of #{MAX_SIGNATURE_LENGTH} characters")
            return false
          end

          # Use shared validation for other checks
          valid_header_value?(signature, "Signature")
        end

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
            header: validator_config[:header] || DEFAULT_CONFIG[:header],
            timestamp_header: validator_config[:timestamp_header],
            timestamp_tolerance: tolerance,
            algorithm: algorithm,
            format: validator_config[:format] || DEFAULT_CONFIG[:format],
            version_prefix: validator_config[:version_prefix] || DEFAULT_CONFIG[:version_prefix],
            payload_template: validator_config[:payload_template],
            header_format: validator_config[:header_format] || DEFAULT_CONFIG[:header_format],
            signature_key: validator_config[:signature_key] || "v1",
            timestamp_key: validator_config[:timestamp_key] || "t",
            structured_header_separator: validator_config[:structured_header_separator] || ",",
            key_value_separator: validator_config[:key_value_separator] || "="
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
        # @api private
        def self.valid_timestamp?(headers, config)
          timestamp_header = config[:timestamp_header]
          tolerance = config[:timestamp_tolerance] || 300
          return false unless timestamp_header

          timestamp_value = headers[timestamp_header.downcase]
          return false unless timestamp_value

          timestamp_validator.valid?(timestamp_value, tolerance)
        end

        # Get timestamp validator instance
        #
        # @return [TimestampValidator] Singleton timestamp validator instance
        # @api private
        def self.timestamp_validator
          @timestamp_validator ||= TimestampValidator.new
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

        # Parse structured signature header containing comma-separated key-value pairs
        #
        # Parses signature headers like "t=1663781880,v1=0123456789abcdef..." used by
        # providers like Tailscale that include multiple values in a single header.
        #
        # @param header_value [String] Raw signature header value
        # @param config [Hash<Symbol, Object>] Validator configuration
        # @return [Hash<Symbol, String>, nil] Parsed data with :signature and :timestamp keys, or nil if parsing fails
        # @note Returns nil if the header format is invalid or required keys are missing
        # @api private
        def self.parse_structured_header(header_value, config)
          signature_key = config[:signature_key]
          timestamp_key = config[:timestamp_key]
          separator = config[:structured_header_separator]
          key_value_separator = config[:key_value_separator]

          # Parse comma-separated key-value pairs
          pairs = {}
          header_value.split(separator).each do |pair|
            key, value = pair.split(key_value_separator, 2)
            return nil if key.nil? || value.nil?

            pairs[key.strip] = value.strip
          end

          # Extract required signature
          signature = pairs[signature_key]
          return nil if signature.nil? || signature.empty?

          result = { signature: signature }

          # Extract optional timestamp
          timestamp = pairs[timestamp_key]
          result[:timestamp] = timestamp if timestamp && !timestamp.empty?

          result
        end
      end
    end
  end
end
