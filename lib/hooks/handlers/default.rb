# frozen_string_literal: true

# Default handler when no custom handler is found
# This handler simply acknowledges receipt of the webhook and shows a few of the built-in features
class DefaultHandler < Hooks::Handlers::Base
  def call(payload:, headers:, config:)

    log.info("🔔 Default handler invoked for webhook 🔔")

    {
      message: "webhook received",
      handler: "DefaultHandler",
      payload_size: payload.is_a?(String) ? payload.length : payload.to_s.length,
      timestamp: Time.now.iso8601
    }
  end
end
