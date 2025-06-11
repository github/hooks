# frozen_string_literal: true

module Hooks
  module Plugins
    module Handlers
      # Base class for all webhook handlers
      #
      # All custom handlers must inherit from this class and implement the #call method
      class Base
        # Process a webhook request
        #
        # @param payload [Hash, String] Parsed request body (JSON Hash) or raw string
        # @param headers [Hash<String, String>] HTTP headers
        # @param config [Hash] Merged endpoint configuration including opts section
        # @return [Hash, String, nil] Response body (will be auto-converted to JSON)
        # @raise [NotImplementedError] if not implemented by subclass
        def call(payload:, headers:, config:)
          raise NotImplementedError, "Handler must implement #call method"
        end

        # Short logger accessor for all subclasses
        # @return [Hooks::Log] Logger instance
        #
        # Provides a convenient way for handlers to log messages without needing
        # to reference the full Hooks::Log namespace.
        #
        # @example Logging an error in an inherited class
        #   log.error("oh no an error occured")
        def log
          Hooks::Log.instance
        end
      end
    end
  end
end
