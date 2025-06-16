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
      # @param request_context [Hash] Context for the request, e.g. request ID, path, handler (optional).
      # @raise [StandardError] Raises error if authentication fails or is misconfigured.
      # @return [void]
      # @note This method will halt execution with an error if authentication fails.
      def validate_auth!(payload, headers, endpoint_config, global_config = {}, request_context = {})
        auth_config = endpoint_config[:auth]
        request_id = request_context&.dig(:request_id)

        # Ensure auth type is present and valid
        auth_type = auth_config&.dig(:type)
        unless auth_type&.is_a?(String) && !auth_type.strip.empty?
          log.error("authentication configuration missing or invalid - request_id: #{request_id}")
          error!({
            error: "authentication_configuration_error",
            message: "authentication configuration missing or invalid",
            request_id:
          }, 500)
        end

        # Get auth plugin from loaded plugins registry (boot-time loaded only)
        begin
          auth_class = Core::PluginLoader.get_auth_plugin(auth_type)
        rescue => e
          log.error("failed to load auth plugin '#{auth_type}': #{e.message} - request_id: #{request_id}")
          error!({
            error: "authentication_plugin_error",
            message: "unsupported auth type '#{auth_type}'",
            request_id:
          }, 400)
        end

        log.debug("validating auth for request with auth_class: #{auth_class.name}")
        unless auth_class.valid?(payload:, headers:, config: endpoint_config)
          log.warn("authentication failed for request with auth_class: #{auth_class.name} - request_id: #{request_id}")
          error!({
            error: "authentication_failed",
            message: "authentication failed",
            request_id:
          }, 401)
        end
      end

      private

      # Short logger accessor for auth module
      # @return [Hooks::Log] Logger instance
      #
      # Provides access to the application logger for authentication operations.
      def log
        Hooks::Log.instance
      end
    end
  end
end
