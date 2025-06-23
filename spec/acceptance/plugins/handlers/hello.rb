# frozen_string_literal: true

class Hello < Hooks::Plugins::Handlers::Base
  def call(payload:, headers:, env:, config:)
    publisher.publish("hello")

    {
      status: "success",
      handler: self.class.name,
      timestamp: Time.now.utc.iso8601,
      messages: publisher.messages,
    }
  end
end
