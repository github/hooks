# frozen_string_literal: true

require "grape"
require "json"
require "securerandom"
require_relative "helpers"
require_relative "../handlers/base"
require_relative "../handlers/default"
require_relative "../core/logger_factory"
require_relative "../core/log"

# import all core endpoint classes dynamically
Dir[File.join(__dir__, "endpoints/**/*.rb")].sort.each do |file|
  require file
end

module Hooks
  module App
    # Factory for creating configured Grape API classes
    class API
      include Hooks::App::Helpers

      # Expose start_time for endpoint modules
      def self.start_time
        @start_time
      end

      # Create a new configured API class
      def self.create(config:, endpoints:, log:)
        # Store startup time for uptime calculation
        @start_time = Time.now

        # Capture values in local variables for closure
        captured_config = config
        captured_endpoints = endpoints
        captured_logger = log

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
          helpers Helpers

          # Mount core operational endpoints
          mount Hooks::App::HealthEndpoint => config[:health_path]
          mount Hooks::App::VersionEndpoint => config[:version_path]

          # Define webhook endpoints dynamically
          captured_endpoints.each do |endpoint_config|
            full_path = "#{captured_config[:root_path]}#{endpoint_config[:path]}"
            handler_class_name = endpoint_config[:handler]

            # Use send to dynamically create POST route
            send(:post, full_path) do
              request_id = uuid

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
            route_path = Hooks::App::CatchallEndpoint.mount_path(captured_config)
            route_block = Hooks::App::CatchallEndpoint.route_block(captured_config, captured_logger)
            post(route_path, &route_block)
          end
        end

        # Return the configured API class
        api_class
      end
    end
  end
end
