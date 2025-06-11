# frozen_string_literal: true

require_relative "config_loader"
require_relative "config_validator"
require_relative "logger_factory"
require_relative "plugin_loader"
require_relative "../app/api"

module Hooks
  module Core
    # Main builder that orchestrates the webhook server setup
    class Builder
      # Initialize builder with configuration options
      #
      # @param config [String, Hash] Path to config file or config hash
      # @param log [Logger] Custom logger instance
      def initialize(config: nil, log: nil)
        @log = log
        @config_input = config
      end

      # Build and return Rack-compatible application
      #
      # @return [Object] Rack-compatible application
      def build
        # Load and validate configuration
        config = load_and_validate_config

        # Create logger unless a custom logger is provided
        if @log.nil?
          @log = LoggerFactory.create(
            log_level: config[:log_level],
            custom_logger: @custom_logger
          )
        end

        # Load all plugins at boot time
        load_plugins(config)

        # Load endpoints
        endpoints = load_endpoints(config)

        # Log startup
        @log.info "starting hooks server v#{Hooks::VERSION}"
        @log.info "config: #{endpoints.size} endpoints loaded"
        @log.info "environment: #{config[:environment]}"
        @log.info "available endpoints: #{endpoints.map { |e| e[:path] }.join(', ')}"

        # Build and return Grape API class
        Hooks::App::API.create(
          config:,
          endpoints:,
          log: @log
        )
      end

      private

      # Load and validate all configuration
      #
      # @return [Hash] Validated global configuration
      def load_and_validate_config
        # Load base config from file/hash and environment
        config = ConfigLoader.load(config_path: @config_input)

        # Validate global configuration
        ConfigValidator.validate_global_config(config)
      rescue ConfigValidator::ValidationError => e
        raise ConfigurationError, "Configuration validation failed: #{e.message}"
      end

      # Load and validate endpoint configurations
      #
      # @param config [Hash] Global configuration
      # @return [Array<Hash>] Array of validated endpoint configurations
      def load_endpoints(config)
        endpoints = ConfigLoader.load_endpoints(config[:endpoints_dir])
        ConfigValidator.validate_endpoints(endpoints)
      rescue ConfigValidator::ValidationError => e
        raise ConfigurationError, "Endpoint validation failed: #{e.message}"
      end

      # Load all plugins at boot time
      #
      # @param config [Hash] Global configuration
      # @return [void]
      def load_plugins(config)
        PluginLoader.load_all_plugins(config)
      rescue => e
        raise ConfigurationError, "Plugin loading failed: #{e.message}"
      end
    end

    # Configuration error
    class ConfigurationError < StandardError; end
  end
end
