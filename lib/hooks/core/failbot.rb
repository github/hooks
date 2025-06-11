# frozen_string_literal: true

module Hooks
  module Core
    # Global failbot component for error reporting
    #
    # This is a stub implementation that does nothing by default.
    # Users can replace this with their own implementation for services
    # like Sentry, Rollbar, etc.
    class Failbot
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

      # Capture an exception during block execution
      #
      # @param context [Hash] Optional context information
      # @return [Object] Return value of the block
      def capture(context = {})
        yield
      rescue => e
        report(e, context)
        raise
      end
    end
  end
end
