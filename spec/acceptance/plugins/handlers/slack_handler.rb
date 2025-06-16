# frozen_string_literal: true

class SlackHandler < Hooks::Plugins::Handlers::Base
  def call(payload:, headers:, env:, config:)
    return {
      status: "success"
    }
  end
end
