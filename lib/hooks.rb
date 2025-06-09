# frozen_string_literal: true

require_relative "hooks/version"
require_relative "hooks/core/builder"
require_relative "hooks/handlers/base"
require_relative "hooks/plugins/lifecycle"

# Load all signature validators
Dir[File.join(__dir__, "hooks/plugins/signature_validator/**/*.rb")].sort.each do |file|
  require file
end

# Main module for the Hooks webhook server framework
module Hooks
  # Build a Rack-compatible webhook server application
  #
  # @param config [String, Hash] Path to config file or config hash
  # @param log [Logger] Custom logger instance (optional)
  # @return [Object] Rack-compatible application
  def self.build(config: nil, log: nil)
    Core::Builder.new(
      config: config,
      log: log,
    ).build
  end
end
