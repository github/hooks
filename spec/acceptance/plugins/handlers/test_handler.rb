# frozen_string_literal: true

class TestHandler < Hooks::Plugins::Handlers::Base
  def call(payload:, headers:, config:)
    {
      status: "test_success",
      payload_received: payload,
      config_opts: config[:opts],
      timestamp: Time.now.iso8601
    }
  end
end
