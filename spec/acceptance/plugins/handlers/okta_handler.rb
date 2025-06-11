# frozen_string_literal: true

class OktaHandler < Hooks::Handlers::Base
  def call(payload:, headers:, config:)
    return {
      status: "success"
    }
  end
end
