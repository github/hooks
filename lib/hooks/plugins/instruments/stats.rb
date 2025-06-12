# frozen_string_literal: true

require_relative "stats_base"

module Hooks
  module Plugins
    module Instruments
      # Default stats instrument implementation
      #
      # This is a stub implementation that does nothing by default.
      # Users can replace this with their own implementation for services
      # like DataDog, New Relic, etc.
      class Stats < StatsBase
        # Record a metric
        #
        # @param metric_name [String] Name of the metric
        # @param value [Numeric] Value to record
        # @param tags [Hash] Optional tags/labels for the metric
        # @return [void]
        def record(metric_name, value, tags = {})
          # Override in subclass for actual metrics reporting
        end

        # Increment a counter
        #
        # @param metric_name [String] Name of the counter
        # @param tags [Hash] Optional tags/labels for the metric
        # @return [void]
        def increment(metric_name, tags = {})
          # Override in subclass for actual metrics reporting
        end

        # Record a timing metric
        #
        # @param metric_name [String] Name of the timing metric
        # @param duration [Numeric] Duration in seconds
        # @param tags [Hash] Optional tags/labels for the metric
        # @return [void]
        def timing(metric_name, duration, tags = {})
          # Override in subclass for actual metrics reporting
        end
      end
    end
  end
end