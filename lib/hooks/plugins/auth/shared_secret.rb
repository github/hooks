# frozen_string_literal: true

require_relative "base"

module Hooks
  module Plugins
    module Auth
      # Generic shared secret validator for webhooks
      #
      # This validator provides simple shared secret authentication for webhook requests.
      # It compares a secret value sent in a configurable HTTP header against the expected
      # secret value. This is a common (though less secure than HMAC) authentication pattern
      # used by various webhook providers.
      #
      # @example Basic configuration
      #   auth:
      #     type: shared_secret
      #     secret_env_key: WEBHOOK_SECRET
      #     header: Authorization
      #
      # @example Custom header configuration
      #   auth:
      #     type: shared_secret
      #     secret_env_key: SOME_OTHER_WEBHOOK_SECRET
      #     header: X-API-Key
      #
      # @note This validator performs direct string comparison of the shared secret.
      #   While simpler than HMAC, it provides less security since the secret is
      #   transmitted directly in the request header.
      class SharedSecret < Base
        # Default configuration values for shared secret validation
        #
        # @return [Hash<Symbol, String>] Default configuration settings
        DEFAULT_CONFIG = {
          header: "Authorization"
        }.freeze

        # Validate shared secret from webhook requests
        #
        # Performs secure comparison of the shared secret value from the configured
        # header against the expected secret. Uses secure comparison to prevent
        # timing attacks.
        #
        # @param payload [String] Raw request body (unused but required by interface)
        # @param headers [Hash<String, String>] HTTP headers from the request
        # @param config [Hash] Endpoint configuration containing validator settings
        # @option config [Hash] :auth Validator-specific configuration
        # @option config [String] :header ('Authorization') Header containing the secret
        # @return [Boolean] true if secret is valid, false otherwise
        # @raise [StandardError] Rescued internally, returns false on any error
        # @note This method is designed to be safe and will never raise exceptions
        # @note Uses Rack::Utils.secure_compare to prevent timing attacks
        # @example Basic validation
        #   SharedSecret.valid?(
        #     payload: request_body,
        #     headers: request.headers,
        #     config: { auth: { header: 'Authorization' } }
        #   )
        def self.valid?(payload:, headers:, config:)
          secret = fetch_secret(config)

          validator_config = build_config(config)

          # Security: Check raw headers BEFORE normalization to detect tampering
          unless headers.respond_to?(:each)
            log.warn("Auth::SharedSecret validation failed: Invalid headers object")
            return false
          end

          secret_header = validator_config[:header]

          # Find the secret header with case-insensitive matching
          raw_secret = find_header_value(headers, secret_header)

          if raw_secret.nil? || raw_secret.empty?
            log.warn("Auth::SharedSecret validation failed: Missing or empty secret header '#{secret_header}'")
            return false
          end

          stripped_secret = raw_secret.strip

          # Security: Reject secrets with leading/trailing whitespace
          if raw_secret != stripped_secret
            log.warn("Auth::SharedSecret validation failed: Secret contains leading/trailing whitespace")
            return false
          end

          # Security: Reject secrets containing null bytes or other control characters
          if raw_secret.match?(/[\u0000-\u001f\u007f-\u009f]/)
            log.warn("Auth::SharedSecret validation failed: Secret contains control characters")
            return false
          end

          # Use secure comparison to prevent timing attacks
          result = Rack::Utils.secure_compare(secret, stripped_secret)
          if result
            log.debug("Auth::SharedSecret validation successful for header '#{secret_header}'")
          else
            log.warn("Auth::SharedSecret validation failed: Signature mismatch")
          end
          result
        rescue StandardError => e
          log.error("Auth::SharedSecret validation failed: #{e.message}")
          false
        end

        private

        # Short logger accessor for auth module
        # @return [Hooks::Log] Logger instance
        def self.log
          Hooks::Log.instance
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

          DEFAULT_CONFIG.merge({
            header: validator_config[:header] || DEFAULT_CONFIG[:header]
          })
        end
      end
    end
  end
end
