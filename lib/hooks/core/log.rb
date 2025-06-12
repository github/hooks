# frozen_string_literal: true

module Hooks
  # Global logger accessor module
  #
  # Provides a singleton-like access pattern for the application logger.
  # The logger instance is set during application initialization and can
  # be accessed throughout the application lifecycle.
  #
  # @example Setting the logger instance
  #   Hooks::Log.instance = Logger.new(STDOUT)
  #
  # @example Accessing the logger
  #   Hooks::Log.instance.info("Application started")
  module Log
    class << self
      # Get or set the global logger instance
      # @return [Logger] The global logger instance
      # @attr_reader instance [Logger] Current logger instance
      # @attr_writer instance [Logger] Set the logger instance
      attr_accessor :instance
    end
  end
end
