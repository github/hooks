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
      end
    end
  end
end
