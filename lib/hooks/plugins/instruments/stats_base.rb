# frozen_string_literal: true

require_relative "../../core/component_access"

module Hooks
  module Plugins
    module Instruments
      # Base class for all stats instrument plugins
      #
      # This class provides the foundation for implementing custom metrics reporting
      # instruments. Subclasses should implement specific methods for their target
      # metrics service (DataDog, New Relic, StatsD, etc.).
      #
      # @abstract Subclass and implement service-specific metrics methods
      # @example Implementing a custom stats instrument
      #   class MyStatsImplementation < Hooks::Plugins::Instruments::StatsBase
      #     def increment(metric_name, tags = {})
      #       # Send increment metric to your service
      #       MyMetricsService.increment(metric_name, tags)
      #       log.debug("Sent increment metric: #{metric_name}")
      #     end
      #
      #     def timing(metric_name, duration, tags = {})
      #       # Send timing metric to your service
      #       MyMetricsService.timing(metric_name, duration, tags)
      #     end
      #   end
      #
      # @see Hooks::Plugins::Instruments::Stats
      class StatsBase
        include Hooks::Core::ComponentAccess

        # Record an increment metric
        #
        # This is a no-op implementation that subclasses should override
        # to provide actual metrics reporting functionality.
        #
        # @param metric_name [String] Name of the metric to increment
        # @param tags [Hash] Optional tags/labels for the metric
        # @return [void]
        # @note Subclasses should implement this method for their specific service
        # @example Override in subclass
        #   def increment(metric_name, tags = {})
        #     statsd.increment(metric_name, tags: tags)
        #   end
        def increment(metric_name, tags = {})
          # No-op implementation for base class
        end

        # Record a timing/duration metric
        #
        # This is a no-op implementation that subclasses should override
        # to provide actual metrics reporting functionality.
        #
        # @param metric_name [String] Name of the timing metric
        # @param duration [Numeric] Duration value (typically in milliseconds)
        # @param tags [Hash] Optional tags/labels for the metric
        # @return [void]
        # @note Subclasses should implement this method for their specific service
        # @example Override in subclass
        #   def timing(metric_name, duration, tags = {})
        #     statsd.timing(metric_name, duration, tags: tags)
        #   end
        def timing(metric_name, duration, tags = {})
          # No-op implementation for base class
        end

        # Record a gauge metric
        #
        # This is a no-op implementation that subclasses should override
        # to provide actual metrics reporting functionality.
        #
        # @param metric_name [String] Name of the gauge metric
        # @param value [Numeric] Current value for the gauge
        # @param tags [Hash] Optional tags/labels for the metric
        # @return [void]
        # @note Subclasses should implement this method for their specific service
        # @example Override in subclass
        #   def gauge(metric_name, value, tags = {})
        #     statsd.gauge(metric_name, value, tags: tags)
        #   end
        def gauge(metric_name, value, tags = {})
          # No-op implementation for base class
        end
      end
    end
  end
end
