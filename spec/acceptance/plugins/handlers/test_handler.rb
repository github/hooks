# frozen_string_literal: true

class TestHandler < Hooks::Plugins::Handlers::Base
  def call(payload:, headers:, config:)
    {
      status: "test_success",
      handler: "TestHandler",
      payload_received: payload,
      config_opts: config[:opts],
      timestamp: Time.now.utc.iso8601
    }
  end
end
