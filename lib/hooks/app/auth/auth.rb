# frozen_string_literal: true

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

        # Get auth plugin from loaded plugins registry (boot-time loaded only)
        begin
          auth_class = Core::PluginLoader.get_auth_plugin(auth_type)
        rescue => e
          error!("unsupported auth type '#{auth_type}'", 400)
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
