# frozen_string_literal: true

require_relative "../../core/component_access"

module Hooks
  module Plugins
    module Instruments
      # Base class for all failbot instrument plugins
      #
      # This class provides the foundation for implementing custom error reporting
      # instruments. Subclasses should implement specific methods for their target
      # error reporting service (Sentry, Rollbar, Honeybadger, etc.).
      #
      # @abstract Subclass and implement service-specific error reporting methods
      # @example Implementing a custom failbot instrument
      #   class MySentryFailbot < Hooks::Plugins::Instruments::FailbotBase
      #     def report(error_or_message, context = {})
      #       case error_or_message
      #       when Exception
      #         Sentry.capture_exception(error_or_message, extra: context)
      #       else
      #         Sentry.capture_message(error_or_message.to_s, extra: context)
      #       end
      #       log.debug("Reported error to Sentry")
      #     end
      #   end
      #
      # @see Hooks::Plugins::Instruments::Failbot
      class FailbotBase
        include Hooks::Core::ComponentAccess

        # Report an error or message to the error tracking service
        #
        # This is a no-op implementation that subclasses should override
        # to provide actual error reporting functionality.
        #
        # @param error_or_message [Exception, String] The error to report or message string
        # @param context [Hash] Additional context information about the error
        # @return [void]
        # @note Subclasses should implement this method for their specific service
        # @example Override in subclass
        #   def report(error_or_message, context = {})
        #     if error_or_message.is_a?(Exception)
        #       ErrorService.report_exception(error_or_message, context)
        #     else
        #       ErrorService.report_message(error_or_message, context)
        #     end
        #   end
        def report(error_or_message, context = {})
          # No-op implementation for base class
        end

        # Report a warning-level message
        #
        # This is a no-op implementation that subclasses should override
        # to provide actual warning reporting functionality.
        #
        # @param message [String] Warning message to report
        # @param context [Hash] Additional context information
        # @return [void]
        # @note Subclasses should implement this method for their specific service
        # @example Override in subclass
        #   def warn(message, context = {})
        #     ErrorService.report_warning(message, context)
        #   end
        def warn(message, context = {})
          # No-op implementation for base class
        end
      end
    end
  end
end
