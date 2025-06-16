# frozen_string_literal: true

module Hooks
  module Plugins
    module Handlers
      # Custom exception class for handler errors
      #
      # This exception is used when handlers call the `error!` method to
      # immediately terminate request processing and return a specific error response.
      # It carries the error details back to the Grape API context where it can be
      # properly formatted and returned to the client.
      #
      # @example Usage in handler
      #   error!({ error: "validation_failed", message: "Invalid payload" }, 400)
      #
      # @see Hooks::Plugins::Handlers::Base#error!
      class Error < StandardError
        # @return [Object] The error body/data to return to the client
        attr_reader :body

        # @return [Integer] The HTTP status code to return
        attr_reader :status

        # Initialize a new handler error
        #
        # @param body [Object] The error body/data to return to the client
        # @param status [Integer] The HTTP status code to return (default: 500)
        def initialize(body, status = 500)
          @body = body
          @status = status.to_i
          super("Handler error: #{status} - #{body}")
        end
      end
    end
  end
end
