# frozen_string_literal: true

# Default webhook handler implementation
#
# This handler provides a basic webhook processing implementation that can be used
# as a fallback when no custom handler is configured for an endpoint. It demonstrates
# the standard handler interface and provides basic logging functionality.
#
# @example Usage in endpoint configuration
#   handler:
#     type: DefaultHandler
#
# @see Hooks::Plugins::Handlers::Base
class DefaultHandler < Hooks::Plugins::Handlers::Base
  # Process a webhook request with basic acknowledgment
  #
  # Provides a simple webhook processing implementation that logs the request
  # and returns a standard acknowledgment response. This is useful for testing
  # webhook endpoints or as a placeholder during development.
  #
  # @param payload [Hash, String] The webhook payload (parsed JSON or raw string)
  # @param headers [Hash<String, String>] HTTP headers from the webhook request
  # @param config [Hash] Endpoint configuration containing handler options
  # @return [Hash] Response indicating successful processing
  # @option config [Hash] :opts Additional handler-specific configuration options
  #
  # @example Basic usage
  #   handler = DefaultHandler.new
  #   response = handler.call(
  #     payload: { "event" => "push" },
  #     headers: { "Content-Type" => "application/json" },
  #     config: { opts: {} }
  #   )
  #   # => { message: "webhook processed successfully", handler: "DefaultHandler", timestamp: "..." }
  def call(payload:, headers:, config:)

    log.info("🔔 Default handler invoked for webhook 🔔")

    # do some basic processing
    if payload
      log.debug("received payload: #{payload.inspect}")
    end

    {
      message: "webhook processed successfully",
      handler: "DefaultHandler",
      timestamp: Time.now.utc.iso8601
    }
  end
end
