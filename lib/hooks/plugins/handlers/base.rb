# frozen_string_literal: true

require_relative "../../core/global_components"
require_relative "../../core/component_access"

module Hooks
  module Plugins
    module Handlers
      # Base class for all webhook handlers
      #
      # All custom handlers must inherit from this class and implement the #call method
      class Base
        include Hooks::Core::ComponentAccess

        # Process a webhook request
        #
        # @param payload [Hash, String] Parsed request body (JSON Hash) or raw string
        # @param headers [Hash] HTTP headers (string keys, optionally normalized - default is normalized)
        # @param config [Hash] Merged endpoint configuration including opts section (symbolized keys)
        # @return [Hash, String, nil] Response body (will be auto-converted to JSON)
        # @raise [NotImplementedError] if not implemented by subclass
        def call(payload:, headers:, config:)
          raise NotImplementedError, "Handler must implement #call method"
        end
      end
    end
  end
end
