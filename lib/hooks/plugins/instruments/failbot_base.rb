# frozen_string_literal: true

module Hooks
  module Plugins
    module Instruments
      # Base class for all failbot instrument plugins
      #
      # All custom failbot implementations must inherit from this class and implement
      # the required methods for error reporting.
      class FailbotBase
        # Short logger accessor for all subclasses
        # @return [Hooks::Log] Logger instance
        #
        # Provides a convenient way for instruments to log messages without needing
        # to reference the full Hooks::Log namespace.
        #
        # @example Logging debug info in an inherited class
        #   log.debug("Sending error to external service")
        def log
          Hooks::Log.instance
        end

        # Report an error or exception
        #
        # @param error_or_message [Exception, String] Exception object or error message
        # @param context [Hash] Optional context information
        # @return [void]
        # @raise [NotImplementedError] if not implemented by subclass
        def report(error_or_message, context = {})
          raise NotImplementedError, "Failbot instrument must implement #report method"
        end

        # Report a critical error
        #
        # @param error_or_message [Exception, String] Exception object or error message
        # @param context [Hash] Optional context information
        # @return [void]
        # @raise [NotImplementedError] if not implemented by subclass
        def critical(error_or_message, context = {})
          raise NotImplementedError, "Failbot instrument must implement #critical method"
        end

        # Report a warning
        #
        # @param message [String] Warning message
        # @param context [Hash] Optional context information
        # @return [void]
        # @raise [NotImplementedError] if not implemented by subclass
        def warning(message, context = {})
          raise NotImplementedError, "Failbot instrument must implement #warning method"
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
end
