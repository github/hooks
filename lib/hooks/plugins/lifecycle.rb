# frozen_string_literal: true

require_relative "../core/global_components"
require_relative "../core/component_access"

module Hooks
  module Plugins
    # Base class for global lifecycle plugins
    #
    # Plugins can hook into request/response/error lifecycle events
    class Lifecycle
      include Hooks::Core::ComponentAccess

      # Called before handler execution
      #
      # @param env [Hash] Rack environment
      def on_request(env)
        # Override in subclass for pre-processing logic
      end

      # Called after successful handler execution
      #
      # @param env [Hash] Rack environment
      # @param response [Hash] Handler response
      def on_response(env, response)
        # Override in subclass for post-processing logic
      end

      # Called when any error occurs during request processing
      #
      # @param exception [Exception] The raised exception
      # @param env [Hash] Rack environment
      def on_error(exception, env)
        # Override in subclass for error handling logic
      end
    end
  end
end
