# frozen_string_literal: true

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
      # @param global_config [Hash] The global configuration (optional, needed for custom auth plugins).
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

        auth_plugin_type = auth_type.downcase

        auth_class = nil

        case auth_plugin_type
        when "hmac"
          auth_class = Plugins::Auth::HMAC
        when "shared_secret"
          auth_class = Plugins::Auth::SharedSecret
        else
          # Try to load custom auth plugin if auth_plugin_dir is configured
          if global_config[:auth_plugin_dir]
            # Convert auth_type to CamelCase class name
            auth_plugin_class_name = auth_type.split("_").map(&:capitalize).join("")

            # Validate the converted class name before attempting to load
            unless valid_auth_plugin_class_name?(auth_plugin_class_name)
              error!("invalid auth plugin type '#{auth_type}'", 400)
            end

            begin
              auth_class = load_auth_plugin(auth_plugin_class_name, global_config[:auth_plugin_dir])
            rescue => e
              error!("failed to load custom auth plugin '#{auth_type}': #{e.message}", 500)
            end
          else
            error!("unsupported auth type '#{auth_type}' due to auth_plugin_dir not being set", 400)
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
    end
  end
end
