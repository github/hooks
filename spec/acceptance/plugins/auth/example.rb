# frozen_string_literal: true

# this is just a super simple example of an auth plugin
# it is not secure and should not be used in production
# it is only for demonstration purposes

module Hooks
  module Plugins
    module Auth
      class Example < Base
        def self.valid?(payload:, headers:, config:)
          # Get the secret from environment variable as configured with secret_env_key
          secret = fetch_secret(config, secret_env_key_name: :secret_env_key)

          # Get the authorization header (case-insensitive)
          auth_header = nil
          headers.each do |key, value|
            if key.downcase == "authorization"
              auth_header = value
              break
            end
          end

          # Check if the header matches our expected format
          return false unless auth_header

          # Extract the token from "Bearer <token>" format
          return false unless auth_header.start_with?("Bearer ")

          token = auth_header[7..-1] # Remove "Bearer " prefix

          # Simple token comparison (in practice, this might be more complex)
          Rack::Utils.secure_compare(token, secret)
        rescue StandardError => e
          log.error("ExampleAuthPlugin failed: #{e.message}")
          false
        end
      end
    end
  end
end
