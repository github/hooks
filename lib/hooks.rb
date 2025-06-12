# frozen_string_literal: true

require_relative "hooks/version"
require_relative "hooks/core/builder"

# Load core components explicitly for better performance and security
require_relative "hooks/core/config_loader"
require_relative "hooks/core/config_validator"
require_relative "hooks/core/logger_factory"
require_relative "hooks/core/plugin_loader"
require_relative "hooks/core/global_components"
require_relative "hooks/core/log"
require_relative "hooks/core/failbot"
require_relative "hooks/core/stats"

# Load essential plugins explicitly
require_relative "hooks/plugins/auth/base"
require_relative "hooks/plugins/auth/hmac"
require_relative "hooks/plugins/auth/shared_secret"
require_relative "hooks/plugins/handlers/base"
require_relative "hooks/plugins/handlers/default"
require_relative "hooks/plugins/lifecycle"
require_relative "hooks/plugins/instruments/stats_base"
require_relative "hooks/plugins/instruments/failbot_base"
require_relative "hooks/plugins/instruments/stats"
require_relative "hooks/plugins/instruments/failbot"

# Load utils explicitly
require_relative "hooks/utils/normalize"
require_relative "hooks/utils/retry"

# Load security module
require_relative "hooks/security"
require_relative "hooks/version"

# Main module for the Hooks webhook server framework
module Hooks
  # Build a Rack-compatible webhook server application
  #
  # @param config [String, Hash] Path to config file or config hash
  # @param log [Logger] Custom logger instance (optional)
  # @return [Object] Rack-compatible application
  def self.build(config: nil, log: nil)
    Core::Builder.new(
      config:,
      log:,
    ).build
  end
end
