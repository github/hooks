# frozen_string_literal: true

require_relative "../core/global_components"

module Hooks
  module Plugins
    # Base class for global lifecycle plugins
    #
    # Plugins can hook into request/response/error lifecycle events
    class Lifecycle
      # Called before handler execution
      #
      # @param env [Hash] Rack environment
      def on_request(env)
        # Override in subclass for pre-processing logic
      end

      # Called after successful handler execution
      #
      # @param env [Hash] Rack environment
      # @param response [Hash] Handler response
      def on_response(env, response)
        # Override in subclass for post-processing logic
      end

      # Called when any error occurs during request processing
      #
      # @param exception [Exception] The raised exception
      # @param env [Hash] Rack environment
      def on_error(exception, env)
        # Override in subclass for error handling logic
      end

      # Global stats component accessor
      # @return [Hooks::Core::Stats] Stats instance for metrics reporting
      #
      # Provides access to the global stats component for reporting metrics
      # to services like DataDog, New Relic, etc.
      #
      # @example Recording a metric in an inherited class
      #   stats.increment("lifecycle.request_processed")
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
      #   failbot.report("Lifecycle hook failed")
      def failbot
        Hooks::Core::GlobalComponents.failbot
      end
    end
  end
end
