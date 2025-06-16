# frozen_string_literal: true

class OktaSetupHandler < Hooks::Plugins::Handlers::Base
  def call(payload:, headers:, env:, config:)
    # Handle Okta's one-time verification challenge
    # Okta sends a GET request with x-okta-verification-challenge header
    # We need to return the challenge value in a JSON response

    log.info("The OktaSetupHandler has been called with the #{env['REQUEST_METHOD']} method")

    verification_challenge = extract_verification_challenge(headers)

    if verification_challenge
      log.info("Processing Okta verification challenge")
      {
        verification: verification_challenge
      }
    else
      log.error("Missing x-okta-verification-challenge header in request")
      {
        error: "Missing verification challenge header",
        expected_header: "x-okta-verification-challenge"
      }
    end
  end

  private

  # Extract the verification challenge from headers (case-insensitive)
  #
  # @param headers [Hash] HTTP headers from the request
  # @return [String, nil] The verification challenge value or nil if not found
  def extract_verification_challenge(headers)
    return nil unless headers.is_a?(Hash)

    # Search for the header case-insensitively
    headers.each do |key, value|
      if key.to_s.downcase == "x-okta-verification-challenge"
        return value
      end
    end

    nil
  end
end
