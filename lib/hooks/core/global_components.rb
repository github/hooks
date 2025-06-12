# frozen_string_literal: true

require_relative "stats"
require_relative "failbot"

module Hooks
  module Core
    # Global registry for shared components accessible throughout the application
    class GlobalComponents
      @stats = Stats.new
      @failbot = Failbot.new

      class << self
        attr_accessor :stats, :failbot
      end

      # Reset components to default instances (for testing)
      #
      # @return [void]
      def self.reset
        @stats = Stats.new
        @failbot = Failbot.new
      end
    end
  end
end
