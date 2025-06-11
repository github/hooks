# frozen_string_literal: true

require "grape"
require "json"
require "securerandom"
require_relative "helpers"
require_relative "auth/auth"
require_relative "../plugins/handlers/base"
require_relative "../plugins/handlers/default"
require_relative "../core/logger_factory"
require_relative "../core/log"

# Import all core endpoint classes dynamically
Dir[File.join(__dir__, "endpoints/**/*.rb")].sort.each { |file| require file }

module Hooks
  module App
    # Factory for creating configured Grape API classes
    class API
      include Hooks::App::Helpers
      include Hooks::App::Auth

      class << self
        attr_reader :start_time
      end

      # Create a new configured API class
      def self.create(config:, endpoints:, log:)
        @start_time = Time.now

        Hooks::Log.instance = log

        api_class = Class.new(Grape::API) do
          content_type :json, "application/json"
          content_type :txt, "text/plain"
          content_type :xml, "application/xml"
          content_type :any, "*/*"
          format :txt
          default_format :txt
        end

        api_class.class_eval do
          helpers Helpers, Auth

          mount Hooks::App::HealthEndpoint => config[:health_path]
          mount Hooks::App::VersionEndpoint => config[:version_path]

          endpoints.each do |endpoint_config|
            full_path = "#{config[:root_path]}#{endpoint_config[:path]}"
            handler_class_name = endpoint_config[:handler]

            post(full_path) do
              request_id = uuid
              request_context = {
                request_id:,
                path: full_path,
                handler: handler_class_name
              }

              Core::LogContext.with(request_context) do
                begin
                  enforce_request_limits(config)
                  request.body.rewind
                  raw_body = request.body.read

                  if endpoint_config[:auth]
                    log.info "validating request (id: #{request_id}, handler: #{handler_class_name})"
                    validate_auth!(raw_body, headers, endpoint_config, config)
                  end

                  payload = parse_payload(raw_body, headers, symbolize: config[:symbolize_payload])
                  handler = load_handler(handler_class_name, config[:handler_plugin_dir])
                  normalized_headers = config[:normalize_headers] ? Hooks::Utils::Normalize.headers(headers) : headers

                  response = handler.call(
                    payload:,
                    headers: normalized_headers,
                    config: endpoint_config
                  )

                  log.info "request processed successfully (id: #{request_id}, handler: #{handler_class_name})"
                  status 200
                  content_type "application/json"
                  (response || { status: "ok" }).to_json
                rescue => e
                  log.error "request failed: #{e.message} (id: #{request_id}, handler: #{handler_class_name})"
                  error_response = {
                    error: e.message,
                    code: determine_error_code(e),
                    request_id: request_id
                  }
                  error_response[:backtrace] = e.backtrace unless config[:production]
                  status error_response[:code]
                  content_type "application/json"
                  error_response.to_json
                end
              end
            end
          end

          if config[:use_catchall_route]
            route_path = Hooks::App::CatchallEndpoint.mount_path(config)
            route_block = Hooks::App::CatchallEndpoint.route_block(config, log)
            post(route_path, &route_block)
          end
        end

        api_class
      end
    end
  end
end
