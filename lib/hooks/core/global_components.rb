# frozen_string_literal: true

module Hooks
  module Core
    # Global registry for shared components accessible throughout the application
    class GlobalComponents
      @test_stats = nil
      @test_failbot = nil

      class << self
        # Get the global stats instance
        # @return [Hooks::Plugins::Instruments::StatsBase] Stats instance for metrics reporting
        def stats
          @test_stats || PluginLoader.get_instrument_plugin(:stats)
        end

        # Get the global failbot instance
        # @return [Hooks::Plugins::Instruments::FailbotBase] Failbot instance for error reporting
        def failbot
          @test_failbot || PluginLoader.get_instrument_plugin(:failbot)
        end

        # Set a custom stats instance (for testing)
        # @param stats_instance [Object] Custom stats instance
        def stats=(stats_instance)
          @test_stats = stats_instance
        end

        # Set a custom failbot instance (for testing)
        # @param failbot_instance [Object] Custom failbot instance
        def failbot=(failbot_instance)
          @test_failbot = failbot_instance
        end

        # Reset components to default instances (for testing)
        #
        # @return [void]
        def reset
          @test_stats = nil
          @test_failbot = nil
          # Clear and reload default instruments
          PluginLoader.clear_plugins
          require_relative "../plugins/instruments/stats"
          require_relative "../plugins/instruments/failbot"
          PluginLoader.instance_variable_set(:@instrument_plugins, {
            stats: Hooks::Plugins::Instruments::Stats.new,
            failbot: Hooks::Plugins::Instruments::Failbot.new
          })
        end
      end
    end
  end
end
