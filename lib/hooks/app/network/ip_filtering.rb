# frozen_string_literal: true

require "ipaddr"
require_relative "../../plugins/handlers/error"

module Hooks
  module App
    module Network
      # Application-level IP filtering functionality
      # Provides both allowlist and blocklist filtering with CIDR support
      class IpFiltering
        # Default IP header to check for client IP
        DEFAULT_IP_HEADER = "X-Forwarded-For"

        # Verifies the incoming request passes the configured IP filtering rules.
        #
        # This method assumes that the client IP address is available in the request headers (e.g., `X-Forwarded-For`).
        # The headers that is used is configurable via the endpoint configuration.
        # It checks the IP address against the allowed and denied lists defined in the endpoint configuration.
        # If the IP address is not allowed, it instantly returns an error response via the `error!` method.
        # If the IP filtering configuration is missing or invalid, it raises an error.
        # If IP filtering is configured at the global level, it will also check against the global configuration first,
        # and then against the endpoint-specific configuration.
        #
        # @param headers [Hash] The request headers.
        # @param endpoint_config [Hash] The endpoint configuration, must include :ip_filtering key.
        # @param global_config [Hash] The global configuration (optional, for compatibility).
        # @param request_context [Hash] Context for the request, e.g. request ID, path, handler (optional).
        # @param env [Hash] The Rack environment
        # @raise [StandardError] Raises error if IP filtering fails or is misconfigured.
        # @return [void]
        # @note This method will halt execution with an error if IP filtering rules fail.
        def self.ip_filtering!(headers, endpoint_config, global_config, request_context, env)
          # Determine which IP filtering configuration to use
          ip_config = resolve_ip_config(endpoint_config, global_config)
          return unless ip_config # No IP filtering configured

          # Extract client IP from headers
          client_ip = extract_client_ip(headers, ip_config)
          return unless client_ip # No client IP found

          # Validate IP against filtering rules
          unless ip_allowed?(client_ip, ip_config)
            request_id = request_context&.dig(:request_id) || request_context&.dig("request_id")
            error_msg = {
              error: "ip_filtering_failed",
              message: "IP address not allowed",
              request_id: request_id
            }
            raise Hooks::Plugins::Handlers::Error.new(error_msg, 403)
          end
        end

        private_class_method def self.resolve_ip_config(endpoint_config, global_config)
          # Endpoint-level configuration takes precedence over global configuration
          endpoint_config[:ip_filtering] || global_config[:ip_filtering]
        end

        private_class_method def self.extract_client_ip(headers, ip_config)
          # Use configured header or default to X-Forwarded-For
          ip_header = ip_config[:ip_header] || DEFAULT_IP_HEADER
          
          # Case-insensitive header lookup
          headers.each do |key, value|
            if key.to_s.downcase == ip_header.downcase
              # X-Forwarded-For can contain multiple IPs, take the first one (original client)
              client_ip = value.to_s.split(",").first&.strip
              return client_ip unless client_ip.nil? || client_ip.empty?
            end
          end
          
          nil
        end

        private_class_method def self.ip_allowed?(client_ip, ip_config)
          # Parse client IP
          begin
            client_addr = IPAddr.new(client_ip)
          rescue IPAddr::InvalidAddressError
            return false # Invalid IP format
          end

          # Check blocklist first (if IP is blocked, deny immediately)
          if ip_config[:blocklist]&.any?
            return false if ip_matches_list?(client_addr, ip_config[:blocklist])
          end

          # Check allowlist (if defined, IP must be in allowlist)
          if ip_config[:allowlist]&.any?
            return ip_matches_list?(client_addr, ip_config[:allowlist])
          end

          # If no allowlist is defined and IP is not in blocklist, allow
          true
        end

        private_class_method def self.ip_matches_list?(client_addr, ip_list)
          ip_list.each do |ip_pattern|
            begin
              pattern_addr = IPAddr.new(ip_pattern.to_s)
              return true if pattern_addr.include?(client_addr)
            rescue IPAddr::InvalidAddressError
              # Skip invalid IP patterns
              next
            end
          end
          false
        end
      end
    end
  end
end