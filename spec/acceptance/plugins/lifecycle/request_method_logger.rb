# frozen_string_literal: true

# This is mostly just an example lifecycle plugin that logs the request method as a demonstration
class RequestMethodLogger < Hooks::Plugins::Lifecycle
  def on_request(env)
    log.debug("on_request called with method: #{env['REQUEST_METHOD']}")
  end

  def on_error(error, env)
    log.error("on_error called with error: #{error.message}")
    failbot.oh_no
  end
end
