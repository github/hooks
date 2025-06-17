# frozen_string_literal: true

require "dry-schema"
require_relative "../security"

module Hooks
  module Core
    # Validates configuration using Dry::Schema
    class ConfigValidator
      # Custom validation error
      class ValidationError < StandardError; end

      # Global configuration schema
      GLOBAL_CONFIG_SCHEMA = Dry::Schema.Params do
        optional(:handler_dir).filled(:string)  # For backward compatibility
        optional(:handler_plugin_dir).filled(:string)
        optional(:auth_plugin_dir).maybe(:string)
        optional(:lifecycle_plugin_dir).maybe(:string)
        optional(:instruments_plugin_dir).maybe(:string)
        optional(:log_level).filled(:string, included_in?: %w[debug info warn error])
        optional(:request_limit).filled(:integer, gt?: 0)
        optional(:request_timeout).filled(:integer, gt?: 0)
        optional(:root_path).filled(:string)
        optional(:health_path).filled(:string)
        optional(:version_path).filled(:string)
        optional(:environment).filled(:string, included_in?: %w[development production])
        optional(:endpoints_dir).filled(:string)
        optional(:use_catchall_route).filled(:bool)
        optional(:normalize_headers).filled(:bool)

        optional(:ip_filtering).hash do
          optional(:ip_header).filled(:string)
          optional(:allowlist).array(:string)
          optional(:blocklist).array(:string)
        end
      end

      # Endpoint configuration schema
      ENDPOINT_CONFIG_SCHEMA = Dry::Schema.Params do
        required(:path).filled(:string)
        required(:handler).filled(:string)
        optional(:method).filled(:string, included_in?: %w[get post put patch delete head options])

        optional(:auth).hash do
          required(:type).filled(:string)
          optional(:secret_env_key).filled(:string)
          optional(:header).filled(:string)
          optional(:algorithm).filled(:string)
          optional(:timestamp_header).filled(:string)
          optional(:timestamp_tolerance).filled(:integer, gt?: 0)
          optional(:format).filled(:string)
          optional(:version_prefix).filled(:string)
          optional(:payload_template).filled(:string)
          optional(:header_format).filled(:string)
          optional(:signature_key).filled(:string)
          optional(:timestamp_key).filled(:string)
          optional(:structured_header_separator).filled(:string)
          optional(:key_value_separator).filled(:string)
        end

        optional(:ip_filtering).hash do
          optional(:ip_header).filled(:string)
          optional(:allowlist).array(:string)
          optional(:blocklist).array(:string)
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

      # Validate endpoint configuration with additional security checks
      #
      # @param config [Hash] Endpoint configuration to validate
      # @return [Hash] Validated configuration
      # @raise [ValidationError] if validation fails
      def self.validate_endpoint_config(config)
        result = ENDPOINT_CONFIG_SCHEMA.call(config)

        if result.failure?
          raise ValidationError, "Invalid endpoint configuration: #{result.errors.to_h}"
        end

        validated_config = result.to_h

        # Security: Additional validation for handler name
        handler_name = validated_config[:handler]
        unless valid_handler_name?(handler_name)
          raise ValidationError, "Invalid handler name: #{handler_name}"
        end

        validated_config
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

      private

      # Validate that a handler name is safe
      #
      # @param handler_name [String] The handler name to validate
      # @return [Boolean] true if the handler name is safe, false otherwise
      def self.valid_handler_name?(handler_name)
        # Must be a string
        return false unless handler_name.is_a?(String)

        # Must not be empty or only whitespace
        return false if handler_name.strip.empty?

        # Must match strict snake_case pattern: starts with lowercase, no trailing/consecutive underscores
        return false unless handler_name.match?(/\A[a-z][a-z0-9]*(?:_[a-z0-9]+)*\z/)

        # Convert to PascalCase for security check (since DANGEROUS_CLASSES uses PascalCase)
        pascal_case_name = handler_name.split("_").map(&:capitalize).join("")
        return false if Hooks::Security::DANGEROUS_CLASSES.include?(pascal_case_name)

        true
      end
    end
  end
end
