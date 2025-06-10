# frozen_string_literal: true

require "grape"
require "json"
require "securerandom"
require_relative "../handlers/base"
require_relative "../core/logger_factory"
require_relative "../core/log"

module Hooks
  module App
    # Factory for creating configured Grape API classes
    class API
      # Create a new configured API class
      def self.create(config:, endpoints:, log:, signal_handler:)
        # Store startup time for uptime calculation
        start_time = Time.now

        # Capture values in local variables for closure
        captured_config = config
        captured_endpoints = endpoints
        captured_logger = log
        _captured_signal_handler = signal_handler
        captured_start_time = start_time

        # Set global logger instance for plugins/validators
        Hooks::Log.instance = log

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
                error!("request body too large", 413)
              end

              # Note: Timeout enforcement would typically be handled at the server level (Puma, etc.)
            end

            # Verify the incoming request using the configured authentication method
            def validate_auth!(payload, headers, endpoint_config)
              auth_config = endpoint_config[:auth]
              auth_plugin_type = auth_config[:type].downcase
              secret_env_key = auth_config[:secret_env_key]

              return unless secret_env_key

              secret = ENV[secret_env_key]
              unless secret
                error!("secret '#{secret_env_key}' not found in environment", 500)
              end

              auth_class = nil

              case auth_plugin_type
              when "hmac"
                auth_class = Plugins::Auth::HMAC
              when "shared_secret"
                auth_class = Plugins::Auth::SharedSecret
              else
                error!("Custom validators not implemented in POC", 500)
              end

              unless auth_class.valid?(
                payload:,
                headers:,
                secret:,
                config: endpoint_config
              )
                error!("authentication failed", 401)
              end
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
              message: "hooks is working!",
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
              log = captured_logger

              # Set request context for logging
              request_context = {
                request_id:,
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

                  # Verify/validate request if configured
                  if endpoint_config[:auth]
                    log.info "validating request (id: #{request_id}, handler: #{handler_class_name})"
                    validate_auth!(raw_body, headers, endpoint_config) if endpoint_config[:auth]
                  end

                  # Parse payload (symbolize_payload is true by default)
                  payload = parse_payload(raw_body, headers, symbolize: config[:symbolize_payload])

                  # Load and instantiate handler
                  handler = load_handler(handler_class_name, config[:handler_dir])

                  # Normalize the headers based on the endpoint configuration (normalization is the default)
                  headers = Hooks::Utils::Normalize.headers(headers) if config[:normalize_headers]

                  # Call handler
                  response = handler.call(
                    payload:,
                    headers:,
                    config: endpoint_config
                  )

                  log.info "request processed successfully (id: #{request_id}, handler: #{handler_class_name})"

                  # Return response as JSON string when using txt format
                  status 200  # Explicitly set status to 200
                  content_type "application/json"
                  (response || { status: "ok" }).to_json

                rescue => e
                  log.error "request failed: #{e.message} (id: #{request_id}, handler: #{handler_class_name})"

                  # Return error response
                  error_response = {
                    error: e.message,
                    code: determine_error_code(e),
                    request_id:
                  }

                  # Add backtrace in all environments except production
                  unless config[:production] == true
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
          # Only create if explicitly enabled in config
          if captured_config[:use_catchall_route]
            post "#{captured_config[:root_path]}/*path" do
              request_id = SecureRandom.uuid
              start_time = Time.now

              # Use captured values
              config = captured_config
              log = captured_logger

              # Set request context for logging
              request_context = {
                request_id:,
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

                  log.info "request processed successfully with default handler (id: #{request_id})"

                  # Return response as JSON string when using txt format
                  status 200
                  content_type "application/json"
                  (response || { status: "ok" }).to_json

                rescue StandardError => e
                  log.error "request failed: #{e.message} (id: #{request_id})"

                  # Return error response
                  error_response = {
                    error: e.message,
                    code: determine_error_code(e),
                    request_id:
                  }

                  # Add backtrace in all environments except production
                  unless config[:production] == true
                    error_response[:backtrace] = e.backtrace
                  end

                  status error_response[:code]
                  content_type "application/json"
                  error_response.to_json
                end
              end
            end
          end
        end

        # Return the configured API class
        api_class
      end

      # Default handler when no custom handler is found
      class DefaultHandler < Handlers::Base
        def call(payload:, headers:, config:)
          {
            message: "webhook received",
            handler: "DefaultHandler",
            payload_size: payload.is_a?(String) ? payload.length : payload.to_s.length,
            timestamp: Time.now.iso8601
          }
        end
      end
    end
  end
end
