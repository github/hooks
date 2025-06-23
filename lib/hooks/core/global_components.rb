# frozen_string_literal: true

require "monitor"

module Hooks
  module Core
    # Global registry for shared components accessible throughout the application
    class GlobalComponents
      @test_stats = nil
      @test_failbot = nil
      @extra_components = {}
      @mutex = Monitor.new

      # Register arbitrary user-defined components. This method is called on application startup
      #
      # @param components [Hash] Hash of component name => component instance
      # @return [void]
      def self.register_extra_components(components)
        @mutex.synchronize do
          @extra_components = components.dup.freeze
        end
      end

      # Get a user-defined component by name
      #
      # @param name [Symbol, String] Component name
      # @return [Object, nil] Component instance or nil if not found
      def self.get_extra_component(name)
        @extra_components[name.to_sym] || @extra_components[name.to_s]
      end

      # Get all registered user component names
      #
      # @return [Array<Symbol>] Array of component names
      def self.extra_component_names
        @extra_components.keys.map(&:to_sym)
      end

      # Check if a user component exists
      #
      # @param name [Symbol, String] Component name
      # @return [Boolean] True if component exists
      def self.extra_component_exists?(name)
        @extra_components.key?(name.to_sym) || @extra_components.key?(name.to_s)
      end

      # Get the global stats instance
      # @return [Hooks::Plugins::Instruments::StatsBase] Stats instance for metrics reporting
      def self.stats
        @test_stats || PluginLoader.get_instrument_plugin(:stats)
      end

      # Get the global failbot instance
      # @return [Hooks::Plugins::Instruments::FailbotBase] Failbot instance for error reporting
      def self.failbot
        @test_failbot || PluginLoader.get_instrument_plugin(:failbot)
      end

      # Set a custom stats instance (for testing)
      # @param stats_instance [Object] Custom stats instance
      def self.stats=(stats_instance)
        @mutex.synchronize do
          @test_stats = stats_instance
        end
      end

      # Set a custom failbot instance (for testing)
      # @param failbot_instance [Object] Custom failbot instance
      def self.failbot=(failbot_instance)
        @mutex.synchronize do
          @test_failbot = failbot_instance
        end
      end

      # Reset components to default instances (for testing)
      #
      # @return [void]
      def self.reset
        @mutex.synchronize do
          @test_stats = nil
          @test_failbot = nil
          @extra_components = {}.freeze
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
