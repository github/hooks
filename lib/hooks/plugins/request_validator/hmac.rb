# frozen_string_literal: true

require "openssl"
require "rack/utils"
require "time"
require_relative "base"

module Hooks
  module Plugins
    module RequestValidator
      # Generic HMAC signature validator for webhooks
      #
      # This validator supports multiple webhook providers with different signature formats:
      # - GitHub: X-Hub-Signature-256: sha256=abc123...
      # - Shopify: X-Shopify-Hmac-Sha256: abc123... (hash only)
      # - Slack: X-Slack-Signature: v0=abc123... (with timestamp validation)
      # - And any other HMAC-based webhook provider
      #
      # @example Basic GitHub-style configuration
      #   request_validator:
      #     type: HMAC
      #     secret_env_key: WEBHOOK_SECRET
      #     header: X-Hub-Signature-256
      #     algorithm: sha256
      #     format: "algorithm=signature"
      #
      # @example Slack-style with timestamp validation
      #   request_validator:
      #     type: HMAC
      #     secret_env_key: SLACK_SIGNING_SECRET
      #     header: X-Slack-Signature
      #     timestamp_header: X-Slack-Request-Timestamp
      #     timestamp_tolerance: 300  # 5 minutes
      #     algorithm: sha256
      #     format: "version=signature"
      #     version_prefix: "v0"
      #     payload_template: "{version}:{timestamp}:{body}"
      class HMAC < Base
        # Default configuration values
        DEFAULT_CONFIG = {
          algorithm: "sha256",
          format: "algorithm=signature",  # GitHub default
          timestamp_tolerance: 300,       # 5 minutes for Slack
          version_prefix: "v0"           # Slack default
        }.freeze

        # Supported signature formats
        FORMATS = {
          "algorithm=signature" => :github_style,    # "sha256=abc123..."
          "signature_only" => :shopify_style,        # "abc123..."
          "version=signature" => :slack_style        # "v0=abc123..."
        }.freeze

        # Validate HMAC signature from webhook requests
        #
        # @param payload [String] Raw request body
        # @param headers [Hash<String, String>] HTTP headers
        # @param secret [String] Secret key for HMAC validation
        # @param config [Hash] Endpoint configuration with signature settings
        # @return [Boolean] true if signature is valid
        def self.valid?(payload:, headers:, secret:, config:)
          return false if secret.nil? || secret.empty?

          validator_config = build_config(config)
          normalized_headers = normalize_headers(headers)

          # Get signature from headers
          signature_header = validator_config[:header]
          provided_signature = normalized_headers[signature_header.downcase]
          return false if provided_signature.nil? || provided_signature.empty?

          # Validate timestamp if required (for Slack and others)
          if validator_config[:timestamp_header]
            return false unless valid_timestamp?(normalized_headers, validator_config)
          end

          # Compute expected signature
          computed_signature = compute_signature(
            payload: payload,
            headers: normalized_headers,
            secret: secret,
            config: validator_config
          )

          # Use secure comparison to prevent timing attacks
          Rack::Utils.secure_compare(computed_signature, provided_signature)
        rescue StandardError => _e
          # Log error in production - for now just return false
          false
        end

        private

        # Build final configuration by merging defaults with provided config
        def self.build_config(config)
          validator_config = config.dig(:request_validator) || {}

          DEFAULT_CONFIG.merge({
            header: validator_config[:header] || "X-Signature",
            timestamp_header: validator_config[:timestamp_header],
            timestamp_tolerance: validator_config[:timestamp_tolerance] || DEFAULT_CONFIG[:timestamp_tolerance],
            algorithm: validator_config[:algorithm] || DEFAULT_CONFIG[:algorithm],
            format: validator_config[:format] || DEFAULT_CONFIG[:format],
            version_prefix: validator_config[:version_prefix] || DEFAULT_CONFIG[:version_prefix],
            payload_template: validator_config[:payload_template]
          })
        end

        # Normalize headers using the Utils::Normalize class
        def self.normalize_headers(headers)
          Utils::Normalize.headers(headers) || {}
        end

        # Validate timestamp if timestamp validation is configured
        def self.valid_timestamp?(headers, config)
          timestamp_header = config[:timestamp_header].downcase
          timestamp_value = headers[timestamp_header]

          return false unless timestamp_value

          timestamp = timestamp_value.to_i
          current_time = Time.now.to_i
          tolerance = config[:timestamp_tolerance]

          (current_time - timestamp).abs <= tolerance
        end

        # Compute HMAC signature based on provider requirements
        def self.compute_signature(payload:, headers:, secret:, config:)
          # Determine what to sign based on payload template
          signing_payload = build_signing_payload(
            payload: payload,
            headers: headers,
            config: config
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

        # Build the payload string to sign (handles Slack's special requirements)
        def self.build_signing_payload(payload:, headers:, config:)
          template = config[:payload_template]

          if template
            # Slack-style: "v0:timestamp:body"
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

        # Format the computed signature based on provider requirements
        def self.format_signature(hash, config)
          format_style = FORMATS[config[:format]]

          case format_style
          when :github_style
            # GitHub: "sha256=abc123..."
            "#{config[:algorithm]}=#{hash}"
          when :shopify_style
            # Shopify: just the hash
            hash
          when :slack_style
            # Slack: "v0=abc123..."
            "#{config[:version_prefix]}=#{hash}"
          else
            # Default to GitHub style
            "#{config[:algorithm]}=#{hash}"
          end
        end
      end
    end
  end
end
