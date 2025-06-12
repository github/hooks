# frozen_string_literal: true

module Hooks
  module Plugins
    module Instruments
      # Base class for all stats instrument plugins
      #
      # All custom stats implementations must inherit from this class and implement
      # the required methods for metrics reporting.
      class StatsBase
        # Short logger accessor for all subclasses
        # @return [Hooks::Log] Logger instance
        #
        # Provides a convenient way for instruments to log messages without needing
        # to reference the full Hooks::Log namespace.
        #
        # @example Logging an error in an inherited class
        #   log.error("Failed to send metric to external service")
        def log
          Hooks::Log.instance
        end
      end
    end
  end
end
