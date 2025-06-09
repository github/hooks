# frozen_string_literal: true

require "grape"
require "json"
require "securerandom"
require_relative "../handlers/base"
require_relative "../plugins/signature_validator/hmac_sha256"
require_relative "../core/logger_factory"

module Hooks
  module App
    # Factory for creating configured Grape API classes
    class API
      # Create a new configured API class
      def self.create(config:, endpoints:, logger:, signal_handler:)
        # Store startup time for uptime calculation
        start_time = Time.now

        # Capture values in local variables for closure
        captured_config = config
        captured_endpoints = endpoints
        captured_logger = logger
        _captured_signal_handler = signal_handler
        captured_start_time = start_time

        # Create the API class with dynamic routes
        api_class = Class.new(Grape::API) do
          # Accept all content types but don't auto-parse
          content_type :json, "application/json"
          content_type :txt, "text/plain"
          content_type :xml, "application/xml"
          content_type :any, "*/*"
          format :txt  # Use text format so no automatic parsing happens
          default_format :txt
        end

        # Use class_eval to dynamically define routes
        api_class.class_eval do
          # Define helper methods first, before routes
          helpers do
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
                error!("Request body too large", 413)
              end

              # Note: Timeout enforcement would typically be handled at the server level (Puma, etc.)
            end

            # Validate request signature
            def validate_signature(payload, headers, endpoint_config)
              signature_config = endpoint_config[:verify_signature]
              validator_type = signature_config[:type] || "default"
              secret_env_key = signature_config[:secret_env_key]

              return unless secret_env_key

              secret = ENV[secret_env_key]
              unless secret
                error!("Secret not found in environment", 500)
              end

              # Use default validator or load custom
              validator_class = if validator_type == "default"
                                  Plugins::SignatureValidator::HmacSha256
              else
                # In a full implementation, we'd dynamically load custom validators
                error!("Custom validators not implemented in POC", 500)
              end

              unless validator_class.valid?(
                payload: payload,
                headers: headers,
                secret: secret,
                config: endpoint_config
              )
                error!("Invalid signature", 401)
              end
            end

            # Parse request payload
            def parse_payload(raw_body, headers)
              content_type = headers["Content-Type"] || headers["CONTENT_TYPE"]

              # Try to parse as JSON if content type suggests it or if it looks like JSON
              if content_type&.include?("application/json") || (raw_body.strip.start_with?("{", "[") rescue false)
                begin
                  return JSON.parse(raw_body)
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
              file_name = handler_class_name.gsub(/([A-Z])/, '_\1').downcase.sub(/^_/, "") + ".rb"
              file_path = File.join(handler_dir, file_name)

              if File.exist?(file_path)
                require file_path
                Object.const_get(handler_class_name).new
              else
                # Create a default handler for POC
                DefaultHandler.new
              end
            rescue => e
              error!("Failed to load handler #{handler_class_name}: #{e.message}", 500)
            end

            # Determine HTTP error code from exception
            def determine_error_code(exception)
              case exception
              when ArgumentError then 400
              when SecurityError then 401
              when NotImplementedError then 501
              else 500
              end
            end
          end

          # Define operational endpoints
          get captured_config[:health_path] do
            content_type "application/json"
            {
              status: "healthy",
              timestamp: Time.now.iso8601,
              version: Hooks::VERSION,
              uptime_seconds: (Time.now - captured_start_time).to_i
            }.to_json
          end

          get captured_config[:metrics_path] do
            content_type "application/json"
            { message: "Metrics functionality removed for simplification" }.to_json
          end

          get captured_config[:version_path] do
            content_type "application/json"
            {
              version: Hooks::VERSION,
              timestamp: Time.now.iso8601
            }.to_json
          end

          # Hello world demo endpoint
          get "#{captured_config[:root_path]}/hello" do
            content_type "application/json"
            {
              message: "Hooks is working!",
              version: Hooks::VERSION,
              timestamp: Time.now.iso8601
            }.to_json
          end

          # Define webhook endpoints dynamically
          captured_endpoints.each do |endpoint_config|
            full_path = "#{captured_config[:root_path]}#{endpoint_config[:path]}"
            handler_class_name = endpoint_config[:handler]

            # Use send to dynamically create POST route
            send(:post, full_path) do
              request_id = SecureRandom.uuid
              start_time = Time.now

              # Use captured values
              config = captured_config
              logger = captured_logger

              # Set request context for logging
              request_context = {
                request_id: request_id,
                path: full_path,
                handler: handler_class_name
              }

              Core::LogContext.with(request_context) do
                begin
                  # Enforce request limits
                  enforce_request_limits(config)

                  # Get raw body for signature validation
                  request.body.rewind
                  raw_body = request.body.read

                  # Validate signature if configured
                  validate_signature(raw_body, headers, endpoint_config) if endpoint_config[:verify_signature]

                  # Parse payload
                  payload = parse_payload(raw_body, headers)

                  # Load and instantiate handler
                  handler = load_handler(handler_class_name, config[:handler_dir])

                  # Call handler
                  response = handler.call(
                    payload: payload,
                    headers: headers,
                    config: endpoint_config
                  )

                  logger.info "Request processed successfully"

                  # Return response as JSON string when using txt format
                  status 200  # Explicitly set status to 200
                  content_type "application/json"
                  (response || { status: "ok" }).to_json

                rescue => e
                  logger.error "Request failed: #{e.message}"

                  # Return error response
                  error_response = {
                    error: e.message,
                    code: determine_error_code(e),
                    request_id: request_id
                  }

                  # Add backtrace in development
                  if config[:environment] == "development"
                    error_response[:backtrace] = e.backtrace
                  end

                  status error_response[:code]
                  content_type "application/json"
                  error_response.to_json
                end
              end
            end
          end

          # Catch-all route for unknown endpoints - use default handler
          post "#{captured_config[:root_path]}/*path" do
            request_id = SecureRandom.uuid
            start_time = Time.now

            # Use captured values
            config = captured_config
            logger = captured_logger

            # Set request context for logging
            request_context = {
              request_id: request_id,
              path: "/#{params[:path]}",
              handler: "DefaultHandler"
            }

            Core::LogContext.with(request_context) do
              begin
                # Enforce request limits
                enforce_request_limits(config)

                # Get raw body for payload parsing
                request.body.rewind
                raw_body = request.body.read

                # Parse payload
                payload = parse_payload(raw_body, headers)

                # Use default handler
                handler = DefaultHandler.new

                # Call handler
                response = handler.call(
                  payload: payload,
                  headers: headers,
                  config: {}
                )

                logger.info "Request processed successfully with default handler"

                # Return response as JSON string when using txt format
                status 200
                content_type "application/json"
                (response || { status: "ok" }).to_json

              rescue => e
                logger.error "Request failed: #{e.message}"

                # Return error response
                error_response = {
                  error: e.message,
                  code: determine_error_code(e),
                  request_id: request_id
                }

                # Add backtrace in development
                if config[:environment] == "development"
                  error_response[:backtrace] = e.backtrace
                end

                status error_response[:code]
                content_type "application/json"
                error_response.to_json
              end
            end
          end
        end

        # Return the configured API class
        api_class
      end

      # Default handler for POC when no custom handler is found
      class DefaultHandler < Handlers::Base
        def call(payload:, headers:, config:)
          {
            message: "Webhook received",
            handler: "DefaultHandler",
            payload_size: payload.is_a?(String) ? payload.length : payload.to_s.length,
            timestamp: Time.now.iso8601
          }
        end
      end
    end
  end
end
