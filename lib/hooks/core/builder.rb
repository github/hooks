# frozen_string_literal: true

require_relative "config_loader"
require_relative "config_validator"
require_relative "logger_factory"
require_relative "signal_handler"
require_relative "../app/api"

module Hooks
  module Core
    # Main builder that orchestrates the webhook server setup
    class Builder
      # Initialize builder with configuration options
      #
      # @param config [String, Hash] Path to config file or config hash
      # @param log [Logger] Custom logger instance
      # @param request_limit [Integer] Maximum request body size in bytes
      # @param request_timeout [Integer] Request timeout in seconds
      # @param root_path [String] Base path for webhook endpoints
      def initialize(config: nil, log: nil, request_limit: nil, request_timeout: nil, root_path: nil)
        @config_input = config
        @custom_logger = log
        @programmatic_overrides = {
          request_limit: request_limit,
          request_timeout: request_timeout,
          root_path: root_path
        }.compact
      end

      # Build and return Rack-compatible application
      #
      # @return [Object] Rack-compatible application
      def build
        # Load and validate configuration
        config = load_and_validate_config

        # Create logger
        logger = LoggerFactory.create(
          log_level: config[:log_level],
          custom_logger: @custom_logger
        )

        # Setup signal handler for graceful shutdown
        signal_handler = SignalHandler.new(logger)

        # Load endpoints
        endpoints = load_endpoints(config)

        # Log startup
        logger.info "Starting Hooks webhook server v#{Hooks::VERSION}"
        logger.info "Config: #{endpoints.size} endpoints loaded"

        # Build and return Grape API class
        Hooks::App::API.create(
          config: config,
          endpoints: endpoints,
          logger: logger,
          signal_handler: signal_handler
        )
      end

      private

      # Load and validate all configuration
      #
      # @return [Hash] Validated global configuration
      def load_and_validate_config
        # Load base config from file/hash and environment
        config = ConfigLoader.load(config_path: @config_input)

        # Apply programmatic overrides (highest priority)
        config.merge!(@programmatic_overrides)

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
    end

    # Configuration error
    class ConfigurationError < StandardError; end
  end
end
