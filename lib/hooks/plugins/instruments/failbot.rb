# frozen_string_literal: true

require_relative "failbot_base"

module Hooks
  module Plugins
    module Instruments
      # Default failbot instrument implementation
      #
      # This is a stub implementation that does nothing by default.
      # Users can replace this with their own implementation for services
      # like Sentry, Rollbar, etc.
      class Failbot < FailbotBase
        # Inherit from FailbotBase to provide a default implementation of the failbot instrument.
      end
    end
  end
end
