# frozen_string_literal: true

class SlackHandler < Hooks::Plugins::Handlers::Base
  def call(payload:, headers:, config:)
    return {
      status: "success"
    }
  end
end
