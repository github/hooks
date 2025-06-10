# frozen_string_literal: true

require "securerandom"

module Hooks
  module App
    module Helpers
      # Generate a unique identifier (UUID)
      def uuid
        SecureRandom.uuid
      end

      # Enforce request size and timeout limits
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
      def load_handler(handler_class_name, handler_dir)
        # Convert class name to file name (e.g., Team1Handler -> team1_handler.rb)
        # E.g.2: GithubHandler -> github_handler.rb
        # E.g.3: GitHubHandler -> git_hub_handler.rb
        file_name = handler_class_name.gsub(/([A-Z])/, '_\1').downcase.sub(/^_/, "") + ".rb"
        file_path = File.join(handler_dir, file_name)

        if File.exist?(file_path)
          require file_path
          Object.const_get(handler_class_name).new
        else
          raise LoadError, "Handler #{handler_class_name} not found at #{file_path}"
        end
      rescue => e
        error!("failed to load handler #{handler_class_name}: #{e.message}", 500)
      end

      # Determine HTTP error code from exception
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
