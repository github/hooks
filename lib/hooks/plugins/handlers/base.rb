# frozen_string_literal: true

require_relative "../../core/global_components"

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

        # Global stats component accessor
        # @return [Hooks::Core::Stats] Stats instance for metrics reporting
        #
        # Provides access to the global stats component for reporting metrics
        # to services like DataDog, New Relic, etc.
        #
        # @example Recording a metric in an inherited class
        #   stats.increment("webhook.processed", { handler: "MyHandler" })
        def stats
          Hooks::Core::GlobalComponents.stats
        end

        # Global failbot component accessor
        # @return [Hooks::Core::Failbot] Failbot instance for error reporting
        #
        # Provides access to the global failbot component for reporting errors
        # to services like Sentry, Rollbar, etc.
        #
        # @example Reporting an error in an inherited class
        #   failbot.report("Something went wrong", { handler: "MyHandler" })
        def failbot
          Hooks::Core::GlobalComponents.failbot
        end
      end
    end
  end
end
