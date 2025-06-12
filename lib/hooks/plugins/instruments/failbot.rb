# frozen_string_literal: true

require_relative "failbot_base"

module Hooks
  module Plugins
    module Instruments
      # Default failbot instrument implementation
      #
      # This is a stub implementation that does nothing by default.
      # Users can replace this with their own implementation for services
      # like Sentry, Rollbar, etc.
      class Failbot < FailbotBase
        # Report an error or exception
        #
        # @param error_or_message [Exception, String] Exception object or error message
        # @param context [Hash] Optional context information
        # @return [void]
        def report(error_or_message, context = {})
          # Override in subclass for actual error reporting
        end

        # Report a critical error
        #
        # @param error_or_message [Exception, String] Exception object or error message
        # @param context [Hash] Optional context information
        # @return [void]
        def critical(error_or_message, context = {})
          # Override in subclass for actual error reporting
        end

        # Report a warning
        #
        # @param message [String] Warning message
        # @param context [Hash] Optional context information
        # @return [void]
        def warning(message, context = {})
          # Override in subclass for actual warning reporting
        end
      end
    end
  end
end