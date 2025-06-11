# frozen_string_literal: true

require "pathname"
require_relative "../../core/plugin_loader"

module Hooks
  module App
    # Provides authentication helpers for verifying incoming requests.
    #
    # @example Usage
    #   include Hooks::App::Auth
    #   validate_auth!(payload, headers, endpoint_config)
    module Auth
      # Verifies the incoming request using the configured authentication method.
      #
      # @param payload [String, Hash] The request payload to authenticate.
      # @param headers [Hash] The request headers.
      # @param endpoint_config [Hash] The endpoint configuration, must include :auth key.
      # @param global_config [Hash] The global configuration (optional, for compatibility).
      # @raise [StandardError] Raises error if authentication fails or is misconfigured.
      # @return [void]
      # @note This method will halt execution with an error if authentication fails.
      def validate_auth!(payload, headers, endpoint_config, global_config = {})
        auth_config = endpoint_config[:auth]

        # Security: Ensure auth type is present and valid
        auth_type = auth_config&.dig(:type)
        unless auth_type&.is_a?(String) && !auth_type.strip.empty?
          error!("authentication configuration missing or invalid", 500)
        end

        # Get auth plugin from loaded plugins registry first
        begin
          auth_class = Core::PluginLoader.get_auth_plugin(auth_type)
        rescue => e
          # If not found in registry and auth_plugin_dir is provided, fall back to dynamic loading
          if global_config[:auth_plugin_dir]
            begin
              auth_class = load_auth_plugin_dynamically(auth_type, global_config[:auth_plugin_dir])
            rescue => fallback_error
              # Preserve specific error messages for better debugging
              if fallback_error.message.include?("not found") ||
                 fallback_error.message.include?("invalid auth plugin") ||
                 fallback_error.message.include?("must inherit from")
                error!(fallback_error.message, 500)
              else
                error!("unsupported auth type '#{auth_type}'", 400)
              end
            end
          else
            error!("unsupported auth type '#{auth_type}'", 400)
          end
        end

        unless auth_class.valid?(
          payload:,
          headers:,
          config: endpoint_config
        )
          error!("authentication failed", 401)
        end
      end

      private

      # Load auth plugin class dynamically (fallback for backward compatibility)
      #
      # @param auth_type [String] The auth type/plugin name
      # @param auth_plugin_dir [String] The directory containing auth plugin files
      # @return [Class] The loaded auth plugin class
      # @raise [StandardError] If the auth plugin cannot be loaded
      def load_auth_plugin_dynamically(auth_type, auth_plugin_dir)
        # Convert auth_type to CamelCase class name
        auth_plugin_class_name = auth_type.split("_").map(&:capitalize).join("")

        # Validate the converted class name before attempting to load
        unless valid_auth_plugin_class_name?(auth_plugin_class_name)
          raise StandardError, "invalid auth plugin type '#{auth_type}'"
        end

        # Convert class name to file name (e.g., SomeCoolAuthPlugin -> some_cool_auth_plugin.rb)
        file_name = auth_plugin_class_name.gsub(/([A-Z])/, '_\1').downcase.sub(/^_/, "") + ".rb"
        file_path = File.join(auth_plugin_dir, file_name)

        # Security: Ensure the file path doesn't escape the auth plugin directory
        normalized_auth_plugin_dir = Pathname.new(File.expand_path(auth_plugin_dir))
        normalized_file_path = Pathname.new(File.expand_path(file_path))
        unless normalized_file_path.descend.any? { |path| path == normalized_auth_plugin_dir }
          raise StandardError, "auth plugin path outside of auth plugin directory"
        end

        if File.exist?(file_path)
          require file_path
          auth_plugin_class = Object.const_get("Hooks::Plugins::Auth::#{auth_plugin_class_name}")

          # Security: Ensure the loaded class inherits from the expected base class
          unless auth_plugin_class < Hooks::Plugins::Auth::Base
            raise StandardError, "auth plugin class must inherit from Hooks::Plugins::Auth::Base"
          end

          auth_plugin_class
        else
          raise StandardError, "Auth plugin #{auth_plugin_class_name} not found at #{file_path}"
        end
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
    end
  end
end
