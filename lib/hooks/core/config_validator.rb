# frozen_string_literal: true

require "dry-schema"

module Hooks
  module Core
    # Validates configuration using Dry::Schema
    class ConfigValidator
      # Custom validation error
      class ValidationError < StandardError; end

      # Global configuration schema
      GLOBAL_CONFIG_SCHEMA = Dry::Schema.Params do
        optional(:handler_dir).filled(:string)
        optional(:log_level).filled(:string, included_in?: %w[debug info warn error])
        optional(:request_limit).filled(:integer, gt?: 0)
        optional(:request_timeout).filled(:integer, gt?: 0)
        optional(:root_path).filled(:string)
        optional(:health_path).filled(:string)
        optional(:version_path).filled(:string)
        optional(:environment).filled(:string, included_in?: %w[development production])
        optional(:endpoints_dir).filled(:string)
        optional(:use_catchall_route).filled(:bool)
        optional(:symbolize_payload).filled(:bool)
        optional(:normalize_headers).filled(:bool)
      end

      # Endpoint configuration schema
      ENDPOINT_CONFIG_SCHEMA = Dry::Schema.Params do
        required(:path).filled(:string)
        required(:handler).filled(:string)

        optional(:request_validator).hash do
          required(:type).filled(:string)
          optional(:secret_env_key).filled(:string)
          optional(:header).filled(:string)
          optional(:algorithm).filled(:string)
          optional(:timestamp_header).filled(:string)
          optional(:timestamp_tolerance).filled(:integer, gt?: 0)
          optional(:format).filled(:string)
          optional(:version_prefix).filled(:string)
          optional(:payload_template).filled(:string)
        end

        optional(:opts).hash
      end

      # Validate global configuration
      #
      # @param config [Hash] Configuration to validate
      # @return [Hash] Validated configuration
      # @raise [ValidationError] if validation fails
      def self.validate_global_config(config)
        result = GLOBAL_CONFIG_SCHEMA.call(config)

        if result.failure?
          raise ValidationError, "Invalid global configuration: #{result.errors.to_h}"
        end

        result.to_h
      end

      # Validate endpoint configuration
      #
      # @param config [Hash] Endpoint configuration to validate
      # @return [Hash] Validated configuration
      # @raise [ValidationError] if validation fails
      def self.validate_endpoint_config(config)
        result = ENDPOINT_CONFIG_SCHEMA.call(config)

        if result.failure?
          raise ValidationError, "Invalid endpoint configuration: #{result.errors.to_h}"
        end

        result.to_h
      end

      # Validate array of endpoint configurations
      #
      # @param endpoints [Array<Hash>] Array of endpoint configurations
      # @return [Array<Hash>] Array of validated configurations
      # @raise [ValidationError] if any validation fails
      def self.validate_endpoints(endpoints)
        validated_endpoints = []

        endpoints.each_with_index do |endpoint, index|
          begin
            validated_endpoints << validate_endpoint_config(endpoint)
          rescue ValidationError => e
            raise ValidationError, "Endpoint #{index}: #{e.message}"
          end
        end

        validated_endpoints
      end
    end
  end
end
