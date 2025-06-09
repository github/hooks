# frozen_string_literal: true

require_relative "hooks/version"
require_relative "hooks/core/builder"
require_relative "hooks/handlers/base"
require_relative "hooks/plugins/lifecycle"
require_relative "hooks/plugins/signature_validator/base"
require_relative "hooks/plugins/signature_validator/hmac_sha256"

# Main module for the Hooks webhook server framework
module Hooks
  # Build a Rack-compatible webhook server application
  #
  # @param config [String, Hash] Path to config file or config hash
  # @param log [Logger] Custom logger instance (optional)
  # @param request_limit [Integer] Maximum request body size in bytes
  # @param request_timeout [Integer] Request timeout in seconds
  # @param root_path [String] Base path for webhook endpoints
  # @return [Object] Rack-compatible application
  def self.build(config: nil, log: nil, request_limit: nil, request_timeout: nil, root_path: nil)
    Core::Builder.new(
      config: config,
      log: log,
      request_limit: request_limit,
      request_timeout: request_timeout,
      root_path: root_path
    ).build
  end
end
