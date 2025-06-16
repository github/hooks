# frozen_string_literal: true

class Boomtown < Hooks::Plugins::Handlers::Base
  def call(payload:, headers:, env:, config:)
    raise StandardError, "Boomtown error occurred"
  end
end
