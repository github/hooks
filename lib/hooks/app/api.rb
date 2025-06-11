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
require_relative "../core/plugin_loader"

# Import all core endpoint classes dynamically
Dir[File.join(__dir__, "endpoints/**/*.rb")].sort.each { |file| require file }

module Hooks
  module App
    # Factory for creating configured Grape API classes
    class API
      include Hooks::App::Helpers
      include Hooks::App::Auth

      class << self
        attr_reader :server_start_time
      end

      # Create a new configured API class
      def self.create(config:, endpoints:, log:)
        @server_start_time = Time.now

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
              start_time = Time.now

              request_context = {
                request_id:,
                path: full_path,
                handler: handler_class_name
              }

              # everything wrapped in the log context has access to the request context and includes it in log messages
              # ex: Hooks::Log.info("message") will include request_id, path, handler, etc
              Core::LogContext.with(request_context) do
                begin
                  # Build Rack environment for lifecycle hooks
                  rack_env = {
                    "REQUEST_METHOD" => request.request_method,
                    "PATH_INFO" => request.path_info,
                    "QUERY_STRING" => request.query_string,
                    "HTTP_VERSION" => request.env["HTTP_VERSION"],
                    "REQUEST_URI" => request.url,
                    "SERVER_NAME" => request.env["SERVER_NAME"],
                    "SERVER_PORT" => request.env["SERVER_PORT"],
                    "CONTENT_TYPE" => request.content_type,
                    "CONTENT_LENGTH" => request.content_length,
                    "REMOTE_ADDR" => request.env["REMOTE_ADDR"],
                    "hooks.request_id" => request_id,
                    "hooks.handler" => handler_class_name,
                    "hooks.endpoint_config" => endpoint_config
                  }

                  # Add HTTP headers to environment
                  headers.each do |key, value|
                    env_key = "HTTP_#{key.upcase.tr('-', '_')}"
                    rack_env[env_key] = value
                  end

                  # Call lifecycle hooks: on_request
                  Core::PluginLoader.lifecycle_plugins.each do |plugin|
                    plugin.on_request(rack_env)
                  end

                  enforce_request_limits(config)
                  request.body.rewind
                  raw_body = request.body.read

                  if endpoint_config[:auth]
                    validate_auth!(raw_body, headers, endpoint_config, config)
                  end

                  payload = parse_payload(raw_body, headers, symbolize: config[:symbolize_payload])
                  handler = load_handler(handler_class_name)
                  normalized_headers = config[:normalize_headers] ? Hooks::Utils::Normalize.headers(headers) : headers

                  response = handler.call(
                    payload:,
                    headers: normalized_headers,
                    config: endpoint_config
                  )

                  # Call lifecycle hooks: on_response
                  Core::PluginLoader.lifecycle_plugins.each do |plugin|
                    plugin.on_response(rack_env, response)
                  end

                  log.info "request processed successfully by handler: #{handler_class_name}"
                  log.debug "request duration: #{Time.now - start_time}s"
                  status 200
                  content_type "application/json"
                  response.to_json
                rescue => e
                  # Call lifecycle hooks: on_error
                  if defined?(rack_env)
                    Core::PluginLoader.lifecycle_plugins.each do |plugin|
                      plugin.on_error(e, rack_env)
                    end
                  end

                  log.error "request failed: #{e.message}"
                  error_response = {
                    error: e.message,
                    code: determine_error_code(e),
                    request_id:
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
