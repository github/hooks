# frozen_string_literal: true

require "pathname"
require_relative "../security"

module Hooks
  module Core
    # Loads and caches all plugins (auth + handlers + lifecycle + instruments) at boot time
    class PluginLoader
      # Class-level registries for loaded plugins
      @auth_plugins = {}
      @handler_plugins = {}
      @lifecycle_plugins = []
      @instrument_plugins = { stats: nil, failbot: nil }

      class << self
        attr_reader :auth_plugins, :handler_plugins, :lifecycle_plugins, :instrument_plugins

        # Load all plugins at boot time
        #
        # @param config [Hash] Global configuration containing plugin directories
        # @return [void]
        def load_all_plugins(config)
          # Clear existing registries
          @auth_plugins = {}
          @handler_plugins = {}
          @lifecycle_plugins = []
          @instrument_plugins = { stats: nil, failbot: nil }

          # Load built-in plugins first
          load_builtin_plugins

          # Load custom plugins if directories are configured
          load_custom_auth_plugins(config[:auth_plugin_dir]) if config[:auth_plugin_dir]
          load_custom_handler_plugins(config[:handler_plugin_dir]) if config[:handler_plugin_dir]
          load_custom_lifecycle_plugins(config[:lifecycle_plugin_dir]) if config[:lifecycle_plugin_dir]
          load_custom_instrument_plugins(config[:instruments_plugin_dir]) if config[:instruments_plugin_dir]

          # Load default instruments if no custom ones were loaded
          load_default_instruments

          # Log loaded plugins
          log_loaded_plugins
        end

        # Get auth plugin class by name
        #
        # @param plugin_name [String] Name of the auth plugin (e.g., "hmac", "shared_secret", "custom_auth")
        # @return [Class] The auth plugin class
        # @raise [StandardError] if plugin not found
        def get_auth_plugin(plugin_name)
          plugin_key = plugin_name.downcase
          plugin_class = @auth_plugins[plugin_key]

          unless plugin_class
            raise StandardError, "Auth plugin '#{plugin_name}' not found. Available plugins: #{@auth_plugins.keys.join(', ')}"
          end

          plugin_class
        end

        # Get handler plugin class by name
        #
        # @param handler_name [String] Name of the handler (e.g., "DefaultHandler", "Team1Handler")
        # @return [Class] The handler plugin class
        # @raise [StandardError] if handler not found
        def get_handler_plugin(handler_name)
          plugin_class = @handler_plugins[handler_name]

          unless plugin_class
            raise StandardError, "Handler plugin '#{handler_name}' not found. Available handlers: #{@handler_plugins.keys.join(', ')}"
          end

          plugin_class
        end

        # Get instrument plugin instance by type
        #
        # @param instrument_type [Symbol] Type of instrument (:stats or :failbot)
        # @return [Object] The instrument plugin instance
        # @raise [StandardError] if instrument not found
        def get_instrument_plugin(instrument_type)
          instrument_instance = @instrument_plugins[instrument_type]

          unless instrument_instance
            raise StandardError, "Instrument plugin '#{instrument_type}' not found"
          end

          instrument_instance
        end

        # Clear all loaded plugins (for testing purposes)
        #
        # @return [void]
        def clear_plugins
          @auth_plugins = {}
          @handler_plugins = {}
          @lifecycle_plugins = []
          @instrument_plugins = { stats: nil, failbot: nil }
        end

        private

        # Load built-in plugins into registries
        #
        # @return [void]
        def load_builtin_plugins
          # Load built-in auth plugins
          @auth_plugins["hmac"] = Hooks::Plugins::Auth::HMAC
          @auth_plugins["shared_secret"] = Hooks::Plugins::Auth::SharedSecret

          # Load built-in handler plugins
          @handler_plugins["DefaultHandler"] = DefaultHandler
        end

        # Load custom auth plugins from directory
        #
        # @param auth_plugin_dir [String] Directory containing custom auth plugins
        # @return [void]
        def load_custom_auth_plugins(auth_plugin_dir)
          return unless auth_plugin_dir && Dir.exist?(auth_plugin_dir)

          Dir.glob(File.join(auth_plugin_dir, "*.rb")).sort.each do |file_path|
            begin
              load_custom_auth_plugin(file_path, auth_plugin_dir)
            rescue StandardError, SyntaxError => e
              raise StandardError, "Failed to load auth plugin from #{file_path}: #{e.message}"
            end
          end
        end

        # Load custom handler plugins from directory
        #
        # @param handler_plugin_dir [String] Directory containing custom handler plugins
        # @return [void]
        def load_custom_handler_plugins(handler_plugin_dir)
          return unless handler_plugin_dir && Dir.exist?(handler_plugin_dir)

          Dir.glob(File.join(handler_plugin_dir, "*.rb")).sort.each do |file_path|
            begin
              load_custom_handler_plugin(file_path, handler_plugin_dir)
            rescue StandardError, SyntaxError => e
              raise StandardError, "Failed to load handler plugin from #{file_path}: #{e.message}"
            end
          end
        end

        # Load custom lifecycle plugins from directory
        #
        # @param lifecycle_plugin_dir [String] Directory containing custom lifecycle plugins
        # @return [void]
        def load_custom_lifecycle_plugins(lifecycle_plugin_dir)
          return unless lifecycle_plugin_dir && Dir.exist?(lifecycle_plugin_dir)

          Dir.glob(File.join(lifecycle_plugin_dir, "*.rb")).sort.each do |file_path|
            begin
              load_custom_lifecycle_plugin(file_path, lifecycle_plugin_dir)
            rescue StandardError, SyntaxError => e
              raise StandardError, "Failed to load lifecycle plugin from #{file_path}: #{e.message}"
            end
          end
        end

        # Load custom instrument plugins from directory
        #
        # @param instruments_plugin_dir [String] Directory containing custom instrument plugins
        # @return [void]
        def load_custom_instrument_plugins(instruments_plugin_dir)
          return unless instruments_plugin_dir && Dir.exist?(instruments_plugin_dir)

          Dir.glob(File.join(instruments_plugin_dir, "*.rb")).sort.each do |file_path|
            begin
              load_custom_instrument_plugin(file_path, instruments_plugin_dir)
            rescue StandardError, SyntaxError => e
              raise StandardError, "Failed to load instrument plugin from #{file_path}: #{e.message}"
            end
          end
        end

        # Load a single custom auth plugin file
        #
        # @param file_path [String] Path to the auth plugin file
        # @param auth_plugin_dir [String] Base directory for auth plugins
        # @return [void]
        def load_custom_auth_plugin(file_path, auth_plugin_dir)
          # Security: Ensure the file path doesn't escape the auth plugin directory
          normalized_auth_plugin_dir = Pathname.new(File.expand_path(auth_plugin_dir))
          normalized_file_path = Pathname.new(File.expand_path(file_path))
          unless normalized_file_path.descend.any? { |path| path == normalized_auth_plugin_dir }
            raise SecurityError, "Auth plugin path outside of auth plugin directory: #{file_path}"
          end

          # Extract plugin name from file (e.g., custom_auth.rb -> CustomAuth)
          file_name = File.basename(file_path, ".rb")
          class_name = file_name.split("_").map(&:capitalize).join("")

          # Security: Validate class name
          unless valid_auth_plugin_class_name?(class_name)
            raise StandardError, "Invalid auth plugin class name: #{class_name}"
          end

          # Load the file
          require file_path

          # Get the class and validate it
          auth_plugin_class = Object.const_get("Hooks::Plugins::Auth::#{class_name}")
          unless auth_plugin_class < Hooks::Plugins::Auth::Base
            raise StandardError, "Auth plugin class must inherit from Hooks::Plugins::Auth::Base: #{class_name}"
          end

          # Register the plugin (using the file_name as the key for lookup)
          @auth_plugins[file_name] = auth_plugin_class
        end

        # Load a single custom handler plugin file
        #
        # @param file_path [String] Path to the handler plugin file
        # @param handler_plugin_dir [String] Base directory for handler plugins
        # @return [void]
        def load_custom_handler_plugin(file_path, handler_plugin_dir)
          # Security: Ensure the file path doesn't escape the handler plugin directory
          normalized_handler_dir = Pathname.new(File.expand_path(handler_plugin_dir))
          normalized_file_path = Pathname.new(File.expand_path(file_path))
          unless normalized_file_path.descend.any? { |path| path == normalized_handler_dir }
            raise SecurityError, "Handler plugin path outside of handler plugin directory: #{file_path}"
          end

          # Extract class name from file (e.g., team1_handler.rb -> Team1Handler)
          file_name = File.basename(file_path, ".rb")
          class_name = file_name.split("_").map(&:capitalize).join("")

          # Security: Validate class name
          unless valid_handler_class_name?(class_name)
            raise StandardError, "Invalid handler class name: #{class_name}"
          end

          # Load the file
          require file_path

          # Get the class and validate it
          handler_class = Object.const_get(class_name)
          unless handler_class < Hooks::Plugins::Handlers::Base
            raise StandardError, "Handler class must inherit from Hooks::Plugins::Handlers::Base: #{class_name}"
          end

          # Register the handler (using the class name as the key for lookup)
          @handler_plugins[class_name] = handler_class
        end

        # Load a single custom lifecycle plugin file
        #
        # @param file_path [String] Path to the lifecycle plugin file
        # @param lifecycle_plugin_dir [String] Base directory for lifecycle plugins
        # @return [void]
        def load_custom_lifecycle_plugin(file_path, lifecycle_plugin_dir)
          # Security: Ensure the file path doesn't escape the lifecycle plugin directory
          normalized_lifecycle_dir = Pathname.new(File.expand_path(lifecycle_plugin_dir))
          normalized_file_path = Pathname.new(File.expand_path(file_path))
          unless normalized_file_path.descend.any? { |path| path == normalized_lifecycle_dir }
            raise SecurityError, "Lifecycle plugin path outside of lifecycle plugin directory: #{file_path}"
          end

          # Extract class name from file (e.g., logging_lifecycle.rb -> LoggingLifecycle)
          file_name = File.basename(file_path, ".rb")
          class_name = file_name.split("_").map(&:capitalize).join("")

          # Security: Validate class name
          unless valid_lifecycle_class_name?(class_name)
            raise StandardError, "Invalid lifecycle plugin class name: #{class_name}"
          end

          # Load the file
          require file_path

          # Get the class and validate it
          lifecycle_class = Object.const_get(class_name)
          unless lifecycle_class < Hooks::Plugins::Lifecycle
            raise StandardError, "Lifecycle plugin class must inherit from Hooks::Plugins::Lifecycle: #{class_name}"
          end

          # Register the plugin instance
          @lifecycle_plugins << lifecycle_class.new
        end

        # Load a single custom instrument plugin file
        #
        # @param file_path [String] Path to the instrument plugin file
        # @param instruments_plugin_dir [String] Base directory for instrument plugins
        # @return [void]
        def load_custom_instrument_plugin(file_path, instruments_plugin_dir)
          # Security: Ensure the file path doesn't escape the instruments plugin directory
          normalized_instruments_dir = Pathname.new(File.expand_path(instruments_plugin_dir))
          normalized_file_path = Pathname.new(File.expand_path(file_path))
          unless normalized_file_path.descend.any? { |path| path == normalized_instruments_dir }
            raise SecurityError, "Instrument plugin path outside of instruments plugin directory: #{file_path}"
          end

          # Extract class name from file (e.g., custom_stats.rb -> CustomStats)
          file_name = File.basename(file_path, ".rb")
          class_name = file_name.split("_").map(&:capitalize).join("")

          # Security: Validate class name
          unless valid_instrument_class_name?(class_name)
            raise StandardError, "Invalid instrument plugin class name: #{class_name}"
          end

          # Load the file
          require file_path

          # Get the class and validate it
          instrument_class = Object.const_get(class_name)

          # Determine instrument type based on inheritance
          if instrument_class < Hooks::Plugins::Instruments::StatsBase
            @instrument_plugins[:stats] = instrument_class.new
          elsif instrument_class < Hooks::Plugins::Instruments::FailbotBase
            @instrument_plugins[:failbot] = instrument_class.new
          else
            raise StandardError, "Instrument plugin class must inherit from StatsBase or FailbotBase: #{class_name}"
          end
        end

        # Load default instrument implementations if no custom ones were loaded
        #
        # @return [void]
        def load_default_instruments
          require_relative "../plugins/instruments/stats"
          require_relative "../plugins/instruments/failbot"

          @instrument_plugins[:stats] ||= Hooks::Plugins::Instruments::Stats.new
          @instrument_plugins[:failbot] ||= Hooks::Plugins::Instruments::Failbot.new
        end

        # Log summary of loaded plugins
        #
        # @return [void]
        def log_loaded_plugins
          return unless defined?(Hooks::Log) && Hooks::Log.instance

          log = Hooks::Log.instance
          # Skip logging if the logger is a test double (class name contains "Double")
          return if log.class.name.include?("Double")

          log.info "Loaded #{@auth_plugins.size} auth plugins: #{@auth_plugins.keys.join(', ')}"
          log.info "Loaded #{@handler_plugins.size} handler plugins: #{@handler_plugins.keys.join(', ')}"
          log.info "Loaded #{@lifecycle_plugins.size} lifecycle plugins"
          log.info "Loaded instruments: #{@instrument_plugins.keys.select { |k| @instrument_plugins[k] }.join(', ')}"
        end

        # Validate that an auth plugin class name is safe to load
        #
        # @param class_name [String] The class name to validate
        # @return [Boolean] true if the class name is safe, false otherwise
        def valid_auth_plugin_class_name?(class_name)
          # Must be a string
          return false unless class_name.is_a?(String)

          # Must not be empty or only whitespace
          return false if class_name.strip.empty?

          # Must match a safe pattern: alphanumeric + underscore, starting with uppercase
          # Examples: MyAuthPlugin, SomeCoolAuthPlugin, CustomAuth
          return false unless class_name.match?(/\A[A-Z][a-zA-Z0-9_]*\z/)

          # Must not be a system/built-in class name
          return false if Hooks::Security::DANGEROUS_CLASSES.include?(class_name)

          true
        end

        # Validate that a handler class name is safe to load
        #
        # @param class_name [String] The class name to validate
        # @return [Boolean] true if the class name is safe, false otherwise
        def valid_handler_class_name?(class_name)
          # Must be a string
          return false unless class_name.is_a?(String)

          # Must not be empty or only whitespace
          return false if class_name.strip.empty?

          # Must match a safe pattern: alphanumeric + underscore, starting with uppercase
          # Examples: MyHandler, Team1Handler, GitHubHandler
          return false unless class_name.match?(/\A[A-Z][a-zA-Z0-9_]*\z/)

          # Must not be a system/built-in class name
          return false if Hooks::Security::DANGEROUS_CLASSES.include?(class_name)

          true
        end

        # Validate that a lifecycle plugin class name is safe to load
        #
        # @param class_name [String] The class name to validate
        # @return [Boolean] true if the class name is safe, false otherwise
        def valid_lifecycle_class_name?(class_name)
          # Must be a string
          return false unless class_name.is_a?(String)

          # Must not be empty or only whitespace
          return false if class_name.strip.empty?

          # Must match a safe pattern: alphanumeric + underscore, starting with uppercase
          # Examples: LoggingLifecycle, MetricsLifecycle, CustomLifecycle
          return false unless class_name.match?(/\A[A-Z][a-zA-Z0-9_]*\z/)

          # Must not be a system/built-in class name
          return false if Hooks::Security::DANGEROUS_CLASSES.include?(class_name)

          true
        end

        # Validate that an instrument plugin class name is safe to load
        #
        # @param class_name [String] The class name to validate
        # @return [Boolean] true if the class name is safe, false otherwise
        def valid_instrument_class_name?(class_name)
          # Must be a string
          return false unless class_name.is_a?(String)

          # Must not be empty or only whitespace
          return false if class_name.strip.empty?

          # Must match a safe pattern: alphanumeric + underscore, starting with uppercase
          # Examples: CustomStats, CustomFailbot, DatadogStats
          return false unless class_name.match?(/\A[A-Z][a-zA-Z0-9_]*\z/)

          # Must not be a system/built-in class name
          return false if Hooks::Security::DANGEROUS_CLASSES.include?(class_name)

          true
        end
      end
    end
  end
end
