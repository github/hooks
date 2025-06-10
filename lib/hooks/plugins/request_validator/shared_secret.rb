# frozen_string_literal: true

require_relative "base"

module Hooks
  module Plugins
    module RequestValidator
      # Generic shared secret validator for webhooks
      #
      # This validator provides simple shared secret authentication for webhook requests.
      # It compares a secret value sent in a configurable HTTP header against the expected
      # secret value. This is a common (though less secure than HMAC) authentication pattern
      # used by various webhook providers.
      #
      # @example Basic configuration
      #   request_validator:
      #     type: shared_secret
      #     secret_env_key: WEBHOOK_SECRET
      #     header: Authorization
      #
      # @example Custom header configuration
      #   request_validator:
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
        # @param secret [String] Expected secret value for comparison
        # @param config [Hash] Endpoint configuration containing validator settings
        # @option config [Hash] :request_validator Validator-specific configuration
        # @option config [String] :header ('Authorization') Header containing the secret
        # @return [Boolean] true if secret is valid, false otherwise
        # @raise [StandardError] Rescued internally, returns false on any error
        # @note This method is designed to be safe and will never raise exceptions
        # @note Uses Rack::Utils.secure_compare to prevent timing attacks
        # @example Basic validation
        #   SharedSecret.valid?(
        #     payload: request_body,
        #     headers: request.headers,
        #     secret: ENV['WEBHOOK_SECRET'],
        #     config: { request_validator: { header: 'Authorization' } }
        #   )
        def self.valid?(payload:, headers:, secret:, config:)
          return false if secret.nil? || secret.empty?

          validator_config = build_config(config)

          # Security: Check raw headers BEFORE normalization to detect tampering
          return false unless headers.respond_to?(:each)

          secret_header = validator_config[:header]

          # Find the secret header with case-insensitive matching but preserve original value
          raw_secret = nil
          headers.each do |key, value|
            if key.to_s.downcase == secret_header.downcase
              raw_secret = value.to_s
              break
            end
          end

          return false if raw_secret.nil? || raw_secret.empty?

          stripped_secret = raw_secret.strip

          # Security: Reject secrets with leading/trailing whitespace
          return false if raw_secret != stripped_secret

          # Security: Reject secrets containing null bytes or other control characters
          return false if raw_secret.match?(/[\u0000-\u001f\u007f-\u009f]/)

          # Use secure comparison to prevent timing attacks
          Rack::Utils.secure_compare(secret, stripped_secret)
        rescue StandardError => _e
          # Log error in production - for now just return false
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
          validator_config = config.dig(:request_validator) || {}

          DEFAULT_CONFIG.merge({
            header: validator_config[:header] || DEFAULT_CONFIG[:header]
          })
        end
      end
    end
  end
end
