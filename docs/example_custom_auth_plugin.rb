# frozen_string_literal: true
# Example custom auth plugin implementation
module Hooks
  module Plugins
    module Auth
      class SomeCoolAuthPlugin < Base
        def self.valid?(payload:, headers:, config:)
          # Get the secret from environment variable
          secret = fetch_secret(config)

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
          token == secret
        end
      end
    end
  end
end
