# frozen_string_literal: true

require "grape"
require "json"
require "securerandom"
require_relative "helpers"
#require_relative "network/ip_filtering"
require_relative "auth/auth"
require_relative "rack_env_builder"
require_relative "../plugins/handlers/base"
require_relative "../plugins/handlers/error"
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
        # :nocov:
        @server_start_time = Time.now

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
            http_method = (endpoint_config[:method] || "post").downcase.to_sym

            send(http_method, full_path) do
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
                  rack_env_builder = RackEnvBuilder.new(
                    request,
                    headers,
                    request_context,
                    endpoint_config,
                    start_time,
                    full_path
                  )
                  rack_env = rack_env_builder.build

                  # Call lifecycle hooks: on_request
                  Core::PluginLoader.lifecycle_plugins.each do |plugin|
                    plugin.on_request(rack_env)
                  end

                  # TODO: IP filtering before processing the request if defined
                  # If IP filtering is enabled at either global or endpoint level, run the filtering rules
                  # before processing the request
                  #if config[:ip_filtering] || endpoint_config[:ip_filtering]
                    #ip_filtering!(headers, endpoint_config, config, request_context, rack_env)
                  #end

                  enforce_request_limits(config, request_context)
                  request.body.rewind
                  raw_body = request.body.read

                  if endpoint_config[:auth]
                    validate_auth!(raw_body, headers, endpoint_config, config, request_context)
                  end

                  payload = parse_payload(raw_body, headers, symbolize: false)
                  handler = load_handler(handler_class_name)
                  processed_headers = config[:normalize_headers] ? Hooks::Utils::Normalize.headers(headers) : headers

                  response = handler.call(
                    payload:,
                    headers: processed_headers,
                    env: rack_env,
                    config: endpoint_config
                  )

                  # Call lifecycle hooks: on_response
                  Core::PluginLoader.lifecycle_plugins.each do |plugin|
                    plugin.on_response(rack_env, response)
                  end

                  log.info("successfully processed webhook event with handler: #{handler_class_name}")
                  log.debug("processing duration: #{Time.now - start_time}s")
                  status 200
                  content_type "application/json"
                  response.to_json
                rescue Hooks::Plugins::Handlers::Error => e
                  # Handler called error! method - immediately return error response and exit the request
                  log.debug("handler #{handler_class_name} called `error!` method")

                  error_response = nil

                  status e.status
                  case e.body
                  when String
                    content_type "text/plain"
                    error_response = e.body
                  else
                    content_type "application/json"
                    error_response = e.body.to_json
                  end

                  return error_response
                rescue StandardError => e
                  err_msg = "Error processing webhook event with handler: #{handler_class_name} - #{e.message} " \
                    "- request_id: #{request_id} - path: #{full_path} - method: #{http_method} - " \
                    "backtrace: #{e.backtrace.join("\n")}"
                  log.error(err_msg)

                  # call lifecycle hooks: on_error if the rack_env is available
                  # if the rack_env is not available, it means the error occurred before we could build it
                  if defined?(rack_env)
                    Core::PluginLoader.lifecycle_plugins.each do |plugin|
                      plugin.on_error(e, rack_env)
                    end
                  end

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
        # :nocov:
      end
    end
  end
end
