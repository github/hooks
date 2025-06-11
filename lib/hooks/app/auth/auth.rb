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
      # @raise [StandardError] Raises error if authentication fails or is misconfigured.
      # @return [void]
      # @note This method will halt execution with an error if authentication fails.
      def validate_auth!(payload, headers, endpoint_config)
        auth_config = endpoint_config[:auth]

        # Security: Ensure auth type is present and valid
        unless auth_config&.dig(:type)&.is_a?(String)
          error!("authentication configuration missing or invalid", 500)
        end

        auth_plugin_type = auth_config[:type].downcase

        auth_class = nil

        case auth_plugin_type
        when "hmac"
          auth_class = Plugins::Auth::HMAC
        when "shared_secret"
          auth_class = Plugins::Auth::SharedSecret
        else
          error!("Custom validators not implemented in POC", 500)
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
