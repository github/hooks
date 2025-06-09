# frozen_string_literal: true

require "openssl"
require "rack/utils"
require_relative "base"

module Hooks
  module Plugins
    module SignatureValidator
      # GitHub webhook signature validator
      #
      # Validates GitHub-style webhook signatures using HMAC SHA256
      class GitHubWebhooks < Base
        # Validate HMAC SHA256 signature from GitHub webhooks
        #
        # official docs: https://docs.github.com/en/webhooks/using-webhooks/validating-webhook-deliveries
        #
        # @param payload [String] Raw request body
        # @param headers [Hash<String, String>] HTTP headers
        # @param secret [String] Secret key for HMAC validation
        # @param config [Hash] Endpoint configuration with signature settings
        # @return [Boolean] true if signature is valid
        def self.valid?(payload:, headers:, secret:, config:)
          return false if secret.nil? || secret.empty?

          signature_header = config.dig(:verify_request, :header) || "X-Hub-Signature-256"
          algorithm = config.dig(:verify_request, :algorithm) || "sha256"

          provided_signature = headers[signature_header]
          return false if provided_signature.nil? || provided_signature.empty?

          # Compute expected signature
          computed_signature = "#{algorithm}=" + OpenSSL::HMAC.hexdigest(
            OpenSSL::Digest.new(algorithm),
            secret,
            payload
          )

          # Use secure comparison to prevent timing attacks
          Rack::Utils.secure_compare(computed_signature, provided_signature)
        rescue => _e
          # Log error in production implementation
          false
        end
      end
    end
  end
end
