# frozen_string_literal: true

require "rack/utils"
require_relative "../../core/log"
require_relative "../../core/global_components"
require_relative "../../core/component_access"

module Hooks
  module Plugins
    module Auth
      # Abstract base class for request validators via authentication
      #
      # All custom Auth plugins must inherit from this class
      class Base
        extend Hooks::Core::ComponentAccess

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
      end
    end
  end
end
