# frozen_string_literal: true

# Default handler when no custom handler is found
# This handler simply acknowledges receipt of the webhook and shows a few of the built-in features
class DefaultHandler < Hooks::Plugins::Handlers::Base
  def call(payload:, headers:, config:)

    log.info("🔔 Default handler invoked for webhook 🔔")

    # do some basic processing
    if payload
      log.debug("received payload: #{payload.inspect}")
    end

    {
      message: "webhook processed successfully",
      handler: "DefaultHandler",
      timestamp: Time.now.iso8601
    }
  end
end
