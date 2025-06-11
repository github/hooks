# frozen_string_literal: true

require "yaml"
require "json"

module Hooks
  module Core
    # Loads and merges configuration from files and environment variables
    class ConfigLoader
      DEFAULT_CONFIG = {
        handler_plugin_dir: "./handlers",
        auth_plugin_dir: nil,
        log_level: "info",
        request_limit: 1_048_576,
        request_timeout: 30,
        root_path: "/webhooks",
        health_path: "/health",
        version_path: "/version",
        environment: "production",
        production: true,
        endpoints_dir: "./config/endpoints",
        use_catchall_route: false,
        symbolize_payload: true,
        normalize_headers: true
      }.freeze

      # Load and merge configuration from various sources
      #
      # @param config_path [String, Hash] Path to config file or config hash
      # @return [Hash] Merged configuration
      def self.load(config_path: nil)
        config = DEFAULT_CONFIG.dup

        # Load from file if path provided
        if config_path.is_a?(String) && File.exist?(config_path)
          file_config = load_config_file(config_path)
          config.merge!(file_config) if file_config
        elsif config_path.is_a?(Hash)
          config.merge!(config_path)
        end

        # Override with environment variables
        config.merge!(load_env_config)

        # Convert string keys to symbols for consistency
        config = symbolize_keys(config)

        if config[:environment] == "production"
          config[:production] = true
        else
          config[:production] = false
        end

        return config
      end

      # Load endpoint configurations from directory
      #
      # @param endpoints_dir [String] Directory containing endpoint config files
      # @return [Array<Hash>] Array of endpoint configurations
      def self.load_endpoints(endpoints_dir)
        return [] unless endpoints_dir && Dir.exist?(endpoints_dir)

        endpoints = []
        files = Dir.glob(File.join(endpoints_dir, "*.{yml,yaml,json}"))

        files.each do |file|
          endpoint_config = load_config_file(file)
          if endpoint_config
            endpoints << symbolize_keys(endpoint_config)
          end
        end

        endpoints
      end

      private

      # Load configuration from YAML or JSON file
      #
      # @param file_path [String] Path to config file
      # @return [Hash, nil] Parsed configuration or nil if error
      def self.load_config_file(file_path)
        content = File.read(file_path)

        result = case File.extname(file_path).downcase
        when ".json"
          JSON.parse(content)
        when ".yml", ".yaml"
          YAML.safe_load(content, permitted_classes: [Symbol])
        else
          nil
        end

        result
      rescue => _e
        # In production, we'd log this error
        nil
      end

      # Load configuration from environment variables
      #
      # @return [Hash] Configuration from ENV vars
      def self.load_env_config
        env_config = {}

        env_mappings = {
          "HOOKS_HANDLER_PLUGIN_DIR" => :handler_plugin_dir,
          "HOOKS_AUTH_PLUGIN_DIR" => :auth_plugin_dir,
          "HOOKS_LOG_LEVEL" => :log_level,
          "HOOKS_REQUEST_LIMIT" => :request_limit,
          "HOOKS_REQUEST_TIMEOUT" => :request_timeout,
          "HOOKS_ROOT_PATH" => :root_path,
          "HOOKS_HEALTH_PATH" => :health_path,
          "HOOKS_VERSION_PATH" => :version_path,
          "HOOKS_ENVIRONMENT" => :environment,
          "HOOKS_ENDPOINTS_DIR" => :endpoints_dir
        }

        env_mappings.each do |env_key, config_key|
          value = ENV[env_key]
          next unless value

          # Convert numeric values
          case config_key
          when :request_limit, :request_timeout
            env_config[config_key] = value.to_i
          else
            env_config[config_key] = value
          end
        end

        env_config
      end

      # Recursively convert string keys to symbols
      #
      # @param obj [Hash, Array, Object] Object to convert
      # @return [Hash, Array, Object] Converted object
      def self.symbolize_keys(obj)
        case obj
        when Hash
          obj.transform_keys(&:to_sym).transform_values { |v| symbolize_keys(v) }
        when Array
          obj.map { |v| symbolize_keys(v) }
        else
          obj
        end
      end
    end
  end
end
