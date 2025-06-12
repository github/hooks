# frozen_string_literal: true

class Hello < Hooks::Plugins::Handlers::Base
  def call(payload:, headers:, config:)
    {
      status: "success",
      handler: self.class.name,
      timestamp: Time.now.utc.iso8601
    }
  end
end
