# frozen_string_literal: true

class BoomtownWithError < Hooks::Plugins::Handlers::Base
  def call(payload:, headers:, env:, config:)

    if payload["boom"] == true
      log.error("boomtown error triggered by payload: #{payload.inspect} - request_id: #{env["hooks.request_id"]}")

      # TODO: Get Grape's `error!` method to work with this
      error!({
        error: "boomtown_with_error",
        message: "the payload triggered a boomtown error",
        request_id: env["hooks.request_id"]
      }, 500)
    end

    return { status: "ok" }
  end
end
