# frozen_string_literal: true

class ResponseSuccessHook < Hooks::Plugins::Lifecycle
  def on_response(env, response)
    stats.success
  end
end
