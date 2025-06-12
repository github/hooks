# frozen_string_literal: true

module Hooks
  module Core
    # Shared module providing access to global components (logger, stats, failbot)
    #
    # This module provides a consistent interface for accessing global components
    # across all plugin types, eliminating code duplication and ensuring consistent
    # behavior throughout the application.
    #
    # @example Usage in a class that needs instance methods
    #   class MyHandler
    #     include Hooks::Core::ComponentAccess
    #
    #     def process
    #       log.info("Processing request")
    #       stats.increment("requests.processed")
    #       failbot.report("Error occurred") if error?
    #     end
    #   end
    #
    # @example Usage in a class that needs class methods
    #   class MyValidator
    #     extend Hooks::Core::ComponentAccess
    #
    #     def self.validate
    #       log.info("Validating request")
    #       stats.increment("requests.validated")
    #     end
    #   end
    module ComponentAccess
      # Short logger accessor
      # @return [Hooks::Log] Logger instance for logging messages
      #
      # Provides a convenient way to log messages without needing
      # to reference the full Hooks::Log namespace.
      #
      # @example Logging an error
      #   log.error("Something went wrong")
      def log
        Hooks::Log.instance
      end

      # Global stats component accessor
      # @return [Hooks::Plugins::Instruments::Stats] Stats instance for metrics reporting
      #
      # Provides access to the global stats component for reporting metrics
      # to services like DataDog, New Relic, etc.
      #
      # @example Recording a metric
      #   stats.increment("webhook.processed", { handler: "MyHandler" })
      def stats
        Hooks::Core::GlobalComponents.stats
      end

      # Global failbot component accessor
      # @return [Hooks::Plugins::Instruments::Failbot] Failbot instance for error reporting
      #
      # Provides access to the global failbot component for reporting errors
      # to services like Sentry, Rollbar, etc.
      #
      # @example Reporting an error
      #   failbot.report("Something went wrong", { context: "additional info" })
      def failbot
        Hooks::Core::GlobalComponents.failbot
      end
    end
  end
end
