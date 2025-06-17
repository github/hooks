# frozen_string_literal: true

class TestHandler < Hooks::Plugins::Handlers::Base
  def call(payload:, headers:, env:, config:)
    {
      status: "test_success",
      handler: "test_handler",
      payload_received: payload,
      env_received: env,
      config_opts: config[:opts],
      timestamp: Time.now.utc.iso8601
    }
  end
end
