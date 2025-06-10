# frozen_string_literal: true

require_relative "hooks/version"
require_relative "hooks/core/builder"
require_relative "hooks/handlers/base"

# Load all plugins (request validators, lifecycle hooks, etc.)
Dir[File.join(__dir__, "hooks/plugins/**/*.rb")].sort.each do |file|
  require file
end

# Load all utils
Dir[File.join(__dir__, "hooks/utils/**/*.rb")].sort.each do |file|
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
      config:,
      log:,
    ).build
  end
end
