# frozen_string_literal: true

require_relative "failbot_base"

module Hooks
  module Plugins
    module Instruments
      # Default failbot instrument implementation
      #
      # This is a no-op implementation that provides the error reporting interface
      # without actually sending errors anywhere. It serves as a safe default when
      # no custom error reporting implementation is configured.
      #
      # Users should replace this with their own implementation for services
      # like Sentry, Rollbar, Honeybadger, etc.
      #
      # @example Replacing with a custom implementation
      #   # In your application initialization:
      #   custom_failbot = MySentryFailbotImplementation.new
      #   Hooks::Core::GlobalComponents.failbot = custom_failbot
      #
      # @see Hooks::Plugins::Instruments::FailbotBase
      # @see Hooks::Core::GlobalComponents
      class Failbot < FailbotBase
        # Inherit from FailbotBase to provide a default no-op implementation
        # of the error reporting instrument interface.
        #
        # All methods from FailbotBase are inherited and provide safe no-op behavior.
      end
    end
  end
end
