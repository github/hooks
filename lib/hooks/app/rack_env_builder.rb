# frozen_string_literal: true

module Hooks
  module App
    # Builds Rack environment hash for lifecycle hooks and handler processing
    #
    # This class centralizes the construction of the Rack environment that gets
    # passed to lifecycle hooks and handlers, ensuring consistency and making
    # it easy to reference the environment structure.
    #
    # @example Building a Rack environment
    #   builder = RackEnvBuilder.new(request, headers, request_context)
    #   rack_env = builder.build
    #
    class RackEnvBuilder
      # Initialize the builder with required components
      #
      # @param request [Grape::Request] The Grape request object
      # @param headers [Hash] Request headers hash
      # @param request_context [Hash] Request context containing metadata
      # @option request_context [String] :request_id Unique request identifier
      # @option request_context [String] :handler Handler class name
      # @param endpoint_config [Hash] Endpoint configuration
      # @param start_time [Time] Request start time
      # @param full_path [String] Full request path including root path
      def initialize(request, headers, request_context, endpoint_config, start_time, full_path)
        @request = request
        @headers = headers
        @request_context = request_context
        @endpoint_config = endpoint_config
        @start_time = start_time
        @full_path = full_path
      end

      # Build the Rack environment hash
      #
      # Constructs a hash containing standard Rack environment variables
      # plus Hooks-specific extensions for lifecycle hooks and handlers.
      #
      # @return [Hash] Complete Rack environment hash
      def build
        rack_env = build_base_environment
        add_http_headers(rack_env)
        rack_env
      end

      private

      # Build the base Rack environment with standard and Hooks-specific variables
      # This pretty much creates everything plus the kitchen sink. It will be very rich in information
      # and will be used by lifecycle hooks and handlers to access request metadata.
      #
      # @return [Hash] Base environment hash
      def build_base_environment
        {
          "REQUEST_METHOD" => @request.request_method,
          "PATH_INFO" => @request.path_info,
          "QUERY_STRING" => @request.query_string,
          "HTTP_VERSION" => @request.env["HTTP_VERSION"],
          "REQUEST_URI" => @request.url,
          "SERVER_NAME" => @request.env["SERVER_NAME"],
          "SERVER_PORT" => @request.env["SERVER_PORT"],
          "CONTENT_TYPE" => @request.content_type,
          "CONTENT_LENGTH" => @request.content_length,
          "REMOTE_ADDR" => @request.env["REMOTE_ADDR"],
          "hooks.request_id" => @request_context[:request_id],
          "hooks.handler" => @request_context[:handler],
          "hooks.endpoint_config" => @endpoint_config,
          "hooks.start_time" => @start_time.iso8601,
          "hooks.full_path" => @full_path
        }
      end

      # Add HTTP headers to the environment with proper Rack naming convention
      #
      # @param rack_env [Hash] Environment hash to modify
      def add_http_headers(rack_env)
        @headers.each do |key, value|
          env_key = "HTTP_#{key.upcase.tr('-', '_')}"
          rack_env[env_key] = value
        end
      end
    end
  end
end
