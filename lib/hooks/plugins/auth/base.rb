# frozen_string_literal: true

require "rack/utils"
require_relative "../../core/log"
require_relative "../../core/global_components"
require_relative "../../core/component_access"
require_relative "timestamp_validator"

module Hooks
  module Plugins
    module Auth
      # Abstract base class for request validators via authentication
      #
      # All custom Auth plugins must inherit from this class
      class Base
        extend Hooks::Core::ComponentAccess

        # Security constants shared across auth validators
        MAX_HEADER_VALUE_LENGTH = ENV.fetch("HOOKS_MAX_HEADER_VALUE_LENGTH", 1024).to_i # Prevent DoS attacks via large header values
        MAX_PAYLOAD_SIZE = ENV.fetch("HOOKS_MAX_PAYLOAD_SIZE", 10 * 1024 * 1024).to_i # 10MB limit for payload validation

        # Validate request
        #
        # @param payload [String] Raw request body
        # @param headers [Hash<String, String>] HTTP headers
        # @param config [Hash] Endpoint configuration
        # @return [Boolean] true if request is valid
        # @raise [NotImplementedError] if not implemented by subclass
        def self.valid?(payload:, headers:, config:)
          raise NotImplementedError, "Validator must implement .valid? class method"
        end

        # Retrieve the secret from the environment variable based on the key set in the configuration
        #
        # Note: This method is intended to be used by subclasses
        # It is a helper method and may not work with all authentication types
        #
        # @param config [Hash] Configuration hash containing :auth key
        # @param secret_env_key [Symbol] The key to look up in the config for the environment variable name
        # @return [String] The secret
        # @raise [StandardError] if secret_env_key is missing or empty
        def self.fetch_secret(config, secret_env_key_name: :secret_env_key)
          secret_env_key = config.dig(:auth, secret_env_key_name)
          if secret_env_key.nil? || !secret_env_key.is_a?(String) || secret_env_key.strip.empty?
            raise StandardError, "authentication configuration incomplete: missing secret_env_key"
          end

          secret = ENV[secret_env_key]

          if secret.nil? || !secret.is_a?(String) || secret.strip.empty?
            raise StandardError, "authentication configuration incomplete: missing secret value for environment variable"
          end

          return secret.strip
        end

        # Get timestamp validator instance
        #
        # @return [TimestampValidator] Singleton timestamp validator instance
        def self.timestamp_validator
          TimestampValidator.new
        end

        # Find a header value by name with case-insensitive matching
        #
        # @param headers [Hash] HTTP headers from the request
        # @param header_name [String] Name of the header to find
        # @return [String, nil] The header value if found, nil otherwise
        # @note This method performs case-insensitive header matching
        def self.find_header_value(headers, header_name)
          return nil unless headers.respond_to?(:each)
          return nil if header_name.nil? || header_name.strip.empty?

          target_header = header_name.downcase
          headers.each do |key, value|
            if key.to_s.downcase == target_header
              return value.to_s
            end
          end
          nil
        end

        # Validate headers object for security issues
        #
        # @param headers [Object] Headers to validate
        # @return [Boolean] true if headers are valid
        def self.valid_headers?(headers)
          unless headers.respond_to?(:each)
            log.warn("Auth validation failed: Invalid headers object")
            return false
          end
          true
        end

        # Validate payload size for security issues
        #
        # @param payload [String] Payload to validate
        # @return [Boolean] true if payload is valid
        def self.valid_payload_size?(payload)
          return true if payload.nil?

          if payload.bytesize > MAX_PAYLOAD_SIZE
            log.warn("Auth validation failed: Payload size exceeds maximum limit of #{MAX_PAYLOAD_SIZE} bytes")
            return false
          end
          true
        end

        # Validate header value for security issues
        #
        # @param header_value [String] Header value to validate
        # @param header_name [String] Header name for logging
        # @return [Boolean] true if header value is valid
        def self.valid_header_value?(header_value, header_name)
          return false if header_value.nil? || header_value.empty?

          # Check length to prevent DoS
          if header_value.length > MAX_HEADER_VALUE_LENGTH
            log.warn("Auth validation failed: #{header_name} exceeds maximum length")
            return false
          end

          # Check for whitespace tampering
          if header_value != header_value.strip
            log.warn("Auth validation failed: #{header_name} contains leading/trailing whitespace")
            return false
          end

          # Check for control characters
          if header_value.match?(/[\u0000-\u001f\u007f-\u009f]/)
            log.warn("Auth validation failed: #{header_name} contains control characters")
            return false
          end

          true
        end
      end
    end
  end
end
