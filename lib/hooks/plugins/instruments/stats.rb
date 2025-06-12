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
        # Inherit from StatsBase to provide a default implementation of the stats instrument.
      end
    end
  end
end
