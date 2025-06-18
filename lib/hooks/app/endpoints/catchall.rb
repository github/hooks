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

      # Set up content types and default format to JSON to match main API
      content_type :json, "application/json"
      content_type :txt, "text/plain"
      content_type :xml, "application/xml"
      content_type :any, "*/*"
      default_format :json

      def self.mount_path(config)
        # :nocov:
        "#{config[:root_path]}/*path"
        # :nocov:
      end

      def self.route_block(captured_config, captured_logger)
        # :nocov:
        proc do
          request_id = uuid
          start_time = Time.now

          # Use captured values
          config = captured_config
          log = captured_logger

          full_path = "#{config[:root_path]}/#{params[:path]}"

          handler_class_name = "DefaultHandler"
          http_method = "post"

          # Set request context for logging
          request_context = {
            request_id:,
            path: full_path,
            handler: handler_class_name
          }

          Hooks::Core::LogContext.with(request_context) do
            begin
              rack_env_builder = RackEnvBuilder.new(
                request,
                headers,
                request_context,
                config,
                start_time,
                full_path
              )
              rack_env = rack_env_builder.build

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
                env: rack_env,
                config: {}
              )

              log.info("successfully processed webhook event with handler: #{handler_class_name}")
              log.debug("processing duration: #{Time.now - start_time}s")
              status 200
              response
            rescue StandardError => e
              err_msg = "Error processing webhook event with handler: #{handler_class_name} - #{e.message} " \
                "- request_id: #{request_id} - path: #{full_path} - method: #{http_method} - " \
                "backtrace: #{e.backtrace.join("\n")}"
              log.error(err_msg)

              # construct a standardized error response
              error_response = {
                error: "server_error",
                message: "an unexpected error occurred while processing the request",
                request_id:
              }

              # enrich the error response with details if not in production
              error_response[:backtrace] = e.backtrace.join("\n") unless config[:production]
              error_response[:message] = e.message unless config[:production]
              error_response[:handler] = handler_class_name unless config[:production]

              status determine_error_code(e)
              error_response
            end
          end
        end
        # :nocov:
      end
    end
  end
end
