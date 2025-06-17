# frozen_string_literal: true

require "securerandom"
require_relative "../security"
require_relative "../core/plugin_loader"
require_relative "network/ip_filtering"

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
      # @param request_context [Hash] Context for the request, e.g. request ID (optional)
      # @raise [StandardError] Halts with error if request body is too large
      # @return [void]
      # @note Timeout enforcement should be handled at the server level (e.g., Puma)
      def enforce_request_limits(config, request_context = {})
        # Optimized content length check - check most common sources first
        content_length = request.content_length if respond_to?(:request) && request.respond_to?(:content_length)

        content_length ||= headers["Content-Length"] ||
                          headers["CONTENT_LENGTH"] ||
                          headers["content-length"] ||
                          headers["HTTP_CONTENT_LENGTH"] ||
                          env["CONTENT_LENGTH"] ||
                          env["HTTP_CONTENT_LENGTH"]

        content_length = content_length&.to_i

        if content_length && content_length > config[:request_limit]
          request_id = request_context&.dig(:request_id)
          error!({ error: "request_body_too_large", message: "request body too large", request_id: }, 413)
        end

        # Note: Timeout enforcement would typically be handled at the server level (Puma, etc.)
      end

      # Parse request payload
      #
      # @param raw_body [String] The raw request body
      # @param headers [Hash] The request headers
      # @param symbolize [Boolean] Whether to symbolize keys in parsed JSON (default: false)
      # @return [Hash, String] Parsed JSON as Hash with string keys, or raw body if not JSON
      def parse_payload(raw_body, headers, symbolize: false)
        # Optimized content type check - check most common header first
        content_type = headers["Content-Type"] || headers["CONTENT_TYPE"] || headers["content-type"] || headers["HTTP_CONTENT_TYPE"]

        # Try to parse as JSON if content type suggests it or if it looks like JSON
        if content_type&.include?("application/json") || (raw_body.strip.start_with?("{", "[") rescue false)
          begin
            # Security: Limit JSON parsing depth and complexity to prevent JSON bombs
            parsed_payload = safe_json_parse(raw_body)
            # Note: symbolize parameter is kept for backward compatibility but defaults to false
            parsed_payload = parsed_payload.transform_keys(&:to_sym) if symbolize && parsed_payload.is_a?(Hash)
            return parsed_payload
          rescue JSON::ParserError, ArgumentError => e
            # If JSON parsing fails or security limits exceeded, return raw body
            if e.message.include?("nesting") || e.message.include?("depth")
              log.warn("JSON parsing limit exceeded: #{e.message}")
            end
          end
        end

        # Return raw body for all other cases
        raw_body
      end

      # Load handler class
      #
      # @param handler_class_name [String] The name of the handler in snake_case (e.g., "github_handler")
      # @return [Object] An instance of the loaded handler class
      # @raise [StandardError] If handler cannot be found
      def load_handler(handler_class_name)
        # Get handler class from loaded plugins registry (the registry is populated at boot time)
        # NOTE: We create a new instance per request (not reuse boot-time instances) because:
        # - Security: Prevents state pollution and information leakage between requests
        # - Thread Safety: Avoids race conditions from shared instance state
        # - Performance: Handler instantiation is fast; reusing instances provides minimal gain
        # - Memory: Allows garbage collection of short-lived objects (Ruby GC optimization)
        handler_class = Core::PluginLoader.get_handler_plugin(handler_class_name)
        return handler_class.new
      end

      # Verifies the incoming request passes the configured IP filtering rules.
      #
      # This method assumes that the client IP address is available in the request headers (e.g., `X-Forwarded-For`).
      # The headers that is used is configurable via the endpoint configuration.
      # It checks the IP address against the allowed and denied lists defined in the endpoint configuration.
      # If the IP address is not allowed, it instantly returns an error response via the `error!` method.
      # If the IP filtering configuration is missing or invalid, it raises an error.
      # If IP filtering is configured at the global level, it will also check against the global configuration first,
      # and then against the endpoint-specific configuration.
      #
      # @param headers [Hash] The request headers.
      # @param endpoint_config [Hash] The endpoint configuration, must include :ip_filtering key.
      # @param global_config [Hash] The global configuration (optional, for compatibility).
      # @param request_context [Hash] Context for the request, e.g. request ID, path, handler (optional).
      # @param env [Hash] The Rack environment
      # @raise [StandardError] Raises error if IP filtering fails or is misconfigured.
      # @return [void]
      # @note This method will halt execution with an error if IP filtering rules fail.
      def ip_filtering!(headers, endpoint_config, global_config, request_context, env)
        Network::IpFiltering.ip_filtering!(headers, endpoint_config, global_config, request_context, env)
      end

      private

      # Safely parse JSON
      #
      # @param json_string [String] The JSON string to parse
      # @return [Hash, Array] Parsed JSON object
      # @raise [JSON::ParserError] If JSON is invalid
      # @raise [ArgumentError] If security limits are exceeded
      def safe_json_parse(json_string)
        # Security limits for JSON parsing
        max_nesting = ENV.fetch("JSON_MAX_NESTING", "20").to_i

        # Additional size check before parsing
        if json_string.length > ENV.fetch("JSON_MAX_SIZE", "10485760").to_i # 10MB default
          raise ArgumentError, "JSON payload too large for parsing"
        end

        JSON.parse(json_string, {
          max_nesting: max_nesting,
          create_additions: false,  # Security: Disable object creation from JSON
          object_class: Hash,       # Use plain Hash instead of custom classes
          array_class: Array        # Use plain Array instead of custom classes
        })
      end

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
