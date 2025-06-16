# frozen_string_literal: true

# !!! IMPORTANT !!!
# This file handles the catchall endpoint for the Hooks application.
# You should not be using catchall endpoints in production.
# This is mainly for development, testing, and demo purposes.
# The logging is limited, lifecycle hooks are not called,
# and it does not support plugins or instruments.
# Use with caution!

require "grape"
require_relative "../../plugins/handlers/default"
require_relative "../helpers"

module Hooks
  module App
    class CatchallEndpoint < Grape::API
      include Hooks::App::Helpers

      def self.mount_path(config)
        # :nocov:
        "#{config[:root_path]}/*path"
        # :nocov:
      end

      def self.route_block(captured_config, captured_logger)
        # :nocov:
        proc do
          request_id = uuid

          # Use captured values
          config = captured_config
          log = captured_logger

          # Set request context for logging
          request_context = {
            request_id:,
            path: "/#{params[:path]}",
            handler: "DefaultHandler"
          }

          Hooks::Core::LogContext.with(request_context) do
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
                payload:,
                headers:,
                env: { # a very limited Rack environment is present for catchall endpoints
                  "REQUEST_METHOD" => request.request_method,
                  "hooks.request_id" => request_id,
                },
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
                request_id: request_id
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
        # :nocov:
      end
    end
  end
end
