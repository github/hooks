# frozen_string_literal: true

# Example handler for GitHub webhooks
class GithubHandler < Hooks::Plugins::Handlers::Base
  # Process GitHub webhook
  #
  # @param payload [Hash, String] GitHub webhook payload
  # @param headers [Hash<String, String>] HTTP headers
  # @param config [Hash] Endpoint configuration
  # @return [Hash] Response data
  def call(payload:, headers:, env:, config:)
    log.info("🚀 Processing GitHub webhook 🚀")
    return {
      status: "success"
    }
  end
end
