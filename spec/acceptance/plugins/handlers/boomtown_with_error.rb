# frozen_string_literal: true

class BoomtownWithError < Hooks::Plugins::Handlers::Base
  def call(payload:, headers:, env:, config:)

    if payload["boom"] == true
      log.error("boomtown error triggered by payload: #{payload.inspect} - request_id: #{env["hooks.request_id"]}")

      # Use Grape's `error!` method to return a custom error response
      error!({
        error: "boomtown_with_error",
        message: "the payload triggered a boomtown error",
        foo: "bar",
        truthy: true,
        payload:,
        headers:,
        request_id: env["hooks.request_id"]
      }, 500)
    end

    return { status: "ok" }
  end
end
