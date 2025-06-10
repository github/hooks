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
        # @param secret [String] Secret key for validation
        # @param config [Hash] Endpoint configuration
        # @return [Boolean] true if request is valid
        # @raise [NotImplementedError] if not implemented by subclass
        def self.valid?(payload:, headers:, secret:, config:)
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
      end
    end
  end
end
