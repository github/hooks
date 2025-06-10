# frozen_string_literal: true

require "rack/utils"

module Hooks
  module Plugins
    module RequestValidator
      # Abstract base class for request validators
      #
      # All custom request validators must inherit from this class
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
      end
    end
  end
end
