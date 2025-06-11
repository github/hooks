# frozen_string_literal: true

require "rack/utils"
require_relative "../../core/log"

module Hooks
  module Plugins
    module Auth
      # Abstract base class for request validators via authentication
      #
      # All custom Auth plugins must inherit from this class
      class Base
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

        # Short logger accessor for all subclasses
        # @return [Hooks::Log] Logger instance for request validation
        #
        # Provides a convenient way for validators to log messages without needing
        # to reference the full Hooks::Log namespace.
        #
        # @example Logging an error in an inherited class
        #   log.error("oh no an error occured")
        def self.log
          Hooks::Log.instance
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
            raise StandardError, "authentication configuration incomplete: missing secret value bound to #{secret_env_key_name}"
          end

          return secret.strip
        end
      end
    end
  end
end
