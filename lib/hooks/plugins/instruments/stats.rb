# frozen_string_literal: true

require_relative "stats_base"

module Hooks
  module Plugins
    module Instruments
      # Default stats instrument implementation
      #
      # This is a no-op implementation that provides the stats interface without
      # actually sending metrics anywhere. It serves as a safe default when no
      # custom stats implementation is configured.
      #
      # Users should replace this with their own implementation for services
      # like DataDog, New Relic, StatsD, etc.
      #
      # @example Replacing with a custom implementation
      #   # In your application initialization:
      #   custom_stats = MyCustomStatsImplementation.new
      #   Hooks::Core::GlobalComponents.stats = custom_stats
      #
      # @see Hooks::Plugins::Instruments::StatsBase
      # @see Hooks::Core::GlobalComponents
      class Stats < StatsBase
        # Inherit from StatsBase to provide a default no-op implementation
        # of the stats instrument interface.
        #
        # All methods from StatsBase are inherited and provide safe no-op behavior.
      end
    end
  end
end
