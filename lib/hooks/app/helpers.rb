# frozen_string_literal: true

require "securerandom"

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
      # @param handler_dir [String] The directory containing handler files
      # @return [Object] An instance of the loaded handler class
      # @raise [LoadError] If the handler file or class cannot be found
      # @raise [StandardError] Halts with error if handler cannot be loaded
      def load_handler(handler_class_name, handler_dir)
        # Security: Validate handler class name to prevent arbitrary class loading
        unless valid_handler_class_name?(handler_class_name)
          error!("invalid handler class name: #{handler_class_name}", 400)
        end

        # Convert class name to file name (e.g., Team1Handler -> team1_handler.rb)
        # E.g.2: GithubHandler -> github_handler.rb
        # E.g.3: GitHubHandler -> git_hub_handler.rb
        file_name = handler_class_name.gsub(/([A-Z])/, '_\1').downcase.sub(/^_/, "") + ".rb"
        file_path = File.join(handler_dir, file_name)

        # Security: Ensure the file path doesn't escape the handler directory
        normalized_handler_dir = File.expand_path(handler_dir)
        normalized_file_path = File.expand_path(file_path)
        unless normalized_file_path.start_with?(normalized_handler_dir)
          error!("handler path outside of handler directory", 400)
        end

        if File.exist?(file_path)
          require file_path
          handler_class = Object.const_get(handler_class_name)

          # Security: Ensure the loaded class inherits from the expected base class
          unless handler_class < Hooks::Handlers::Base
            error!("handler class must inherit from Hooks::Handlers::Base", 400)
          end

          handler_class.new
        else
          raise LoadError, "Handler #{handler_class_name} not found at #{file_path}"
        end
      rescue => e
        error!("failed to load handler: #{e.message}", 500)
      end

      private

      # Validate that a handler class name is safe to load
      #
      # @param class_name [String] The class name to validate
      # @return [Boolean] true if the class name is safe, false otherwise
      def valid_handler_class_name?(class_name)
        # Must be a string
        return false unless class_name.is_a?(String)

        # Must not be empty or only whitespace
        return false if class_name.strip.empty?

        # Must match a safe pattern: alphanumeric + underscore, starting with uppercase
        # Examples: MyHandler, GitHubHandler, Team1Handler
        return false unless class_name.match?(/\A[A-Z][a-zA-Z0-9_]*\z/)

        # Must not be a system/built-in class name
        dangerous_classes = %w[
          File Dir Kernel Object Class Module Proc Method
          IO Socket TCPSocket UDPSocket BasicSocket
          Process Thread Fiber Mutex ConditionVariable
          Marshal YAML JSON Pathname
        ]
        return false if dangerous_classes.include?(class_name)

        true
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
