# frozen_string_literal: true

require_relative "../../core/global_components"
require_relative "../../core/component_access"
require_relative "error"

module Hooks
  module Plugins
    module Handlers
      # Base class for all webhook handlers
      #
      # All custom handlers must inherit from this class and implement the #call method
      class Base
        include Hooks::Core::ComponentAccess

        # Process a webhook request
        #
        # @param payload [Hash, String] Parsed request body (JSON Hash) or raw string
        # @param headers [Hash] HTTP headers (string keys, optionally normalized - default is normalized)
        # @param env [Hash] Rack environment (contains the request context, headers, etc - very rich context)
        # @param config [Hash] Merged endpoint configuration including opts section (symbolized keys)
        # @return [Hash, String, nil] Response body (will be auto-converted to JSON)
        # @raise [NotImplementedError] if not implemented by subclass
        def call(payload:, headers:, env:, config:)
          raise NotImplementedError, "Handler must implement #call method"
        end

        # Terminate request processing with a custom error response
        #
        # This method provides the same interface as Grape's `error!` method,
        # allowing handlers to immediately stop processing and return a specific
        # error response to the client.
        #
        # @param body [Object] The error body/data to return to the client
        # @param status [Integer] The HTTP status code to return (default: 500)
        # @raise [Hooks::Plugins::Handlers::Error] Always raises to terminate processing
        #
        # @example Return a custom error with status 400
        #   error!({ error: "validation_failed", message: "Invalid payload" }, 400)
        #
        # @example Return a simple string error with status 401
        #   error!("Unauthorized", 401)
        #
        # @example Return an error with default 500 status
        #   error!({ error: "internal_error", message: "Something went wrong" })
        def error!(body, status = 500)
          raise Error.new(body, status)
        end
      end
    end
  end
end
