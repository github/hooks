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

        # Record a metric
        #
        # @param metric_name [String] Name of the metric
        # @param value [Numeric] Value to record
        # @param tags [Hash] Optional tags/labels for the metric
        # @return [void]
        # @raise [NotImplementedError] if not implemented by subclass
        def record(metric_name, value, tags = {})
          raise NotImplementedError, "Stats instrument must implement #record method"
        end

        # Increment a counter
        #
        # @param metric_name [String] Name of the counter
        # @param tags [Hash] Optional tags/labels for the metric
        # @return [void]
        # @raise [NotImplementedError] if not implemented by subclass
        def increment(metric_name, tags = {})
          raise NotImplementedError, "Stats instrument must implement #increment method"
        end

        # Record a timing metric
        #
        # @param metric_name [String] Name of the timing metric
        # @param duration [Numeric] Duration in seconds
        # @param tags [Hash] Optional tags/labels for the metric
        # @return [void]
        # @raise [NotImplementedError] if not implemented by subclass
        def timing(metric_name, duration, tags = {})
          raise NotImplementedError, "Stats instrument must implement #timing method"
        end

        # Measure execution time of a block
        #
        # @param metric_name [String] Name of the timing metric
        # @param tags [Hash] Optional tags/labels for the metric
        # @return [Object] Return value of the block
        def measure(metric_name, tags = {})
          start_time = Time.now
          result = yield
          duration = Time.now - start_time
          timing(metric_name, duration, tags)
          result
        end
      end
    end
  end
end
