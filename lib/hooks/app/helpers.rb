# frozen_string_literal: true

require "securerandom"
require_relative "../security"
require_relative "../core/plugin_loader"

module Hooks
  module App
    module Helpers
      # Generate a unique identifier (UUID)
      #
      # @return [String] a new UUID string
      def uuid
        SecureRandom.uuid
      end

      # Enforce request size and timeout limits
      #
      # @param config [Hash] The configuration hash, must include :request_limit
      # @raise [StandardError] Halts with error if request body is too large
      # @return [void]
      # @note Timeout enforcement should be handled at the server level (e.g., Puma)
      def enforce_request_limits(config)
        # Check content length (handle different header formats and sources)
        content_length = headers["Content-Length"] || headers["CONTENT_LENGTH"] ||
                        headers["content-length"] || headers["HTTP_CONTENT_LENGTH"] ||
                        env["CONTENT_LENGTH"] || env["HTTP_CONTENT_LENGTH"]

        # Also try to get from request object directly
        content_length ||= request.content_length if respond_to?(:request) && request.respond_to?(:content_length)

        content_length = content_length&.to_i

        if content_length && content_length > config[:request_limit]
          error!("request body too large", 413)
        end

        # Note: Timeout enforcement would typically be handled at the server level (Puma, etc.)
      end

      # Parse request payload
      #
      # @param raw_body [String] The raw request body
      # @param headers [Hash] The request headers
      # @param symbolize [Boolean] Whether to symbolize keys in parsed JSON (default: true)
      # @return [Hash, String] Parsed JSON as Hash (optionally symbolized), or raw body if not JSON
      def parse_payload(raw_body, headers, symbolize: true)
        content_type = headers["Content-Type"] || headers["CONTENT_TYPE"] || headers["content-type"] || headers["HTTP_CONTENT_TYPE"]

        # Try to parse as JSON if content type suggests it or if it looks like JSON
        if content_type&.include?("application/json") || (raw_body.strip.start_with?("{", "[") rescue false)
          begin
            parsed_payload = JSON.parse(raw_body)
            parsed_payload = parsed_payload.transform_keys(&:to_sym) if symbolize && parsed_payload.is_a?(Hash)
            return parsed_payload
          rescue JSON::ParserError
            # If JSON parsing fails, return raw body
          end
        end

        # Return raw body for all other cases
        raw_body
      end

      # Load handler class
      #
      # @param handler_class_name [String] The name of the handler class to load
      # @param handler_dir [String] The directory containing handler files (unused - kept for compatibility)
      # @return [Object] An instance of the loaded handler class
      # @raise [StandardError] If handler cannot be found
      def load_handler(handler_class_name, handler_dir = nil)
        # Get handler class from loaded plugins registry (boot-time loaded only)
        begin
          handler_class = Core::PluginLoader.get_handler_plugin(handler_class_name)
          return handler_class.new
        rescue => e
          error!("failed to get handler '#{handler_class_name}': #{e.message}", 500)
        end
      end

      public

      # Load auth plugin class (DEPRECATED - plugins are now loaded at boot time)
      #
      # @deprecated This method is kept for compatibility but auth plugins are now loaded at boot time
      # @param auth_plugin_class_name [String] The name of the auth plugin class to load
      # @param auth_plugin_dir [String] The directory containing auth plugin files
      # @return [Class] The loaded auth plugin class
      # @raise [StandardError] Always raises error as dynamic loading is no longer supported
      def load_auth_plugin(auth_plugin_class_name, auth_plugin_dir)
        error!("Dynamic auth plugin loading is deprecated. Auth plugins are now loaded at boot time.", 500)
      end

      private

      # Determine HTTP error code from exception
      #
      # @param exception [Exception] The exception to map to an HTTP status code
      # @return [Integer] The HTTP status code (400, 501, or 500)
      def determine_error_code(exception)
        case exception
        when ArgumentError then 400
        when NotImplementedError then 501
        else 500
        end
      end
    end
  end
end
