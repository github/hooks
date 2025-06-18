# frozen_string_literal: true

require "ipaddr"
require_relative "../../plugins/handlers/error"

module Hooks
  module Core
    module Network
      # Application-level IP filtering functionality for HTTP requests.
      #
      # This class provides robust IP filtering capabilities supporting both allowlist
      # and blocklist filtering with CIDR notation support. It can extract client IP
      # addresses from various HTTP headers and validate them against configured rules.
      #
      # The filtering logic follows these rules:
      # 1. If a blocklist is configured and the IP matches, access is denied
      # 2. If an allowlist is configured, the IP must match to be allowed
      # 3. If no allowlist is configured and IP is not blocked, access is allowed
      #
      # @example Basic usage with endpoint configuration
      #   config = {
      #     ip_filtering: {
      #       allowlist: ["192.168.1.0/24", "10.0.0.1"],
      #       blocklist: ["192.168.1.100"],
      #       ip_header: "X-Real-IP"
      #     }
      #   }
      #   IpFiltering.ip_filtering!(headers, config, {}, {}, env)
      #
      # @note This class is designed to work with Rack-based applications and
      #   expects headers to be in a Hash format.
      class IpFiltering
        # Default HTTP header to check for client IP address.
        # @return [String] the default header name
        DEFAULT_IP_HEADER = "X-Forwarded-For"

        # Verifies that an incoming request passes the configured IP filtering rules.
        #
        # This method extracts the client IP address from request headers and validates
        # it against configured allowlist and blocklist rules. The method will halt
        # execution by raising an error if the IP filtering rules fail.
        #
        # The IP filtering configuration can be defined at both global and endpoint levels,
        # with endpoint configuration taking precedence. If no IP filtering is configured,
        # the method returns early without performing any checks.
        #
        # The client IP is extracted from HTTP headers, with support for configurable
        # header names. The default header is X-Forwarded-For, which can contain multiple
        # comma-separated IPs (the first IP is used as the original client).
        #
        # @param headers [Hash] The request headers as key-value pairs
        # @param endpoint_config [Hash] The endpoint-specific configuration containing :ip_filtering
        # @param global_config [Hash] The global configuration (optional, for compatibility)
        # @param request_context [Hash] Context information for the request (e.g., request_id, path, handler)
        # @param env [Hash] The Rack environment hash
        #
        # @raise [Hooks::Plugins::Handlers::Error] Raises a 403 error if IP filtering rules fail
        # @return [void] Returns nothing if IP filtering passes or is not configured
        #
        # @example Successful IP filtering
        #   headers = { "X-Forwarded-For" => "192.168.1.50" }
        #   config = { ip_filtering: { allowlist: ["192.168.1.0/24"] } }
        #   IpFiltering.ip_filtering!(headers, config, {}, { request_id: "123" }, env)
        #
        # @example IP filtering failure
        #   headers = { "X-Forwarded-For" => "10.0.0.1" }
        #   config = { ip_filtering: { allowlist: ["192.168.1.0/24"] } }
        #   # Raises Hooks::Plugins::Handlers::Error with 403 status
        #   IpFiltering.ip_filtering!(headers, config, {}, { request_id: "123" }, env)
        #
        # @note This method assumes that the client IP address is available in the request headers
        # @note If the IP filtering configuration is missing or invalid, it raises an error
        # @note This method will halt execution with an error if IP filtering rules fail
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

        # Resolves the IP filtering configuration to use for the current request.
        #
        # This method determines which IP filtering configuration should be applied
        # by checking endpoint-specific configuration first, then falling back to
        # global configuration. This allows for flexible configuration inheritance
        # with endpoint-level overrides.
        #
        # @param endpoint_config [Hash] The endpoint-specific configuration
        # @param global_config [Hash] The global application configuration
        #
        # @return [Hash, nil] The IP filtering configuration hash, or nil if none configured
        #
        # @example With endpoint configuration
        #   endpoint_config = { ip_filtering: { allowlist: ["192.168.1.0/24"] } }
        #   global_config = { ip_filtering: { allowlist: ["10.0.0.0/8"] } }
        #   resolve_ip_config(endpoint_config, global_config)
        #   # => { allowlist: ["192.168.1.0/24"] }
        #
        # @example With only global configuration
        #   endpoint_config = {}
        #   global_config = { ip_filtering: { allowlist: ["10.0.0.0/8"] } }
        #   resolve_ip_config(endpoint_config, global_config)
        #   # => { allowlist: ["10.0.0.0/8"] }
        #
        # @note Endpoint-level configuration takes precedence over global configuration
        private_class_method def self.resolve_ip_config(endpoint_config, global_config)
          # Endpoint-level configuration takes precedence over global configuration
          endpoint_config[:ip_filtering] || global_config[:ip_filtering]
        end

        # Extracts the client IP address from request headers.
        #
        # This method looks for the client IP in the specified header (or default
        # X-Forwarded-For header). It performs case-insensitive header matching
        # and handles comma-separated IP lists by taking the first IP address,
        # which represents the original client in proxy chains.
        #
        # @param headers [Hash] The request headers as key-value pairs
        # @param ip_config [Hash] The IP filtering configuration containing :ip_header
        #
        # @return [String, nil] The client IP address, or nil if not found or empty
        #
        # @example Extracting from X-Forwarded-For
        #   headers = { "X-Forwarded-For" => "192.168.1.50, 10.0.0.1" }
        #   ip_config = { ip_header: "X-Forwarded-For" }
        #   extract_client_ip(headers, ip_config)
        #   # => "192.168.1.50"
        #
        # @example Extracting from custom header
        #   headers = { "X-Real-IP" => "203.0.113.45" }
        #   ip_config = { ip_header: "X-Real-IP" }
        #   extract_client_ip(headers, ip_config)
        #   # => "203.0.113.45"
        #
        # @note Case-insensitive header lookup is performed
        # @note For comma-separated IP lists, only the first IP is returned
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

        # Determines if a client IP address is allowed based on filtering rules.
        #
        # This method implements the core IP filtering logic by checking the client
        # IP against configured blocklist and allowlist rules. The filtering follows
        # these precedence rules:
        # 1. If blocklist exists and IP matches, deny access (return false)
        # 2. If allowlist exists, IP must match to be allowed (return true/false)
        # 3. If no allowlist exists and IP not blocked, allow access (return true)
        #
        # @param client_ip [String] The client IP address to validate
        # @param ip_config [Hash] The IP filtering configuration containing :blocklist and/or :allowlist
        #
        # @return [Boolean] true if IP is allowed, false if blocked or invalid
        #
        # @example IP allowed by allowlist
        #   client_ip = "192.168.1.50"
        #   ip_config = { allowlist: ["192.168.1.0/24"] }
        #   ip_allowed?(client_ip, ip_config)
        #   # => true
        #
        # @example IP blocked by blocklist
        #   client_ip = "192.168.1.100"
        #   ip_config = { blocklist: ["192.168.1.100"] }
        #   ip_allowed?(client_ip, ip_config)
        #   # => false
        #
        # @example Invalid IP format
        #   client_ip = "invalid-ip"
        #   ip_config = { allowlist: ["192.168.1.0/24"] }
        #   ip_allowed?(client_ip, ip_config)
        #   # => false
        #
        # @note Invalid IP addresses are automatically denied
        # @note Blocklist rules take precedence over allowlist rules
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

        # Checks if a client IP address matches any pattern in an IP list.
        #
        # This method iterates through a list of IP patterns (which can include
        # individual IPs or CIDR ranges) and determines if the client IP matches
        # any of them. It uses Ruby's IPAddr class for robust IP address and
        # CIDR range matching, with error handling for invalid IP patterns.
        #
        # @param client_addr [IPAddr] The client IP address as an IPAddr object
        # @param ip_list [Array<String>] Array of IP patterns (IPs or CIDR ranges)
        #
        # @return [Boolean] true if client IP matches any pattern in the list, false otherwise
        #
        # @example Matching individual IP
        #   client_addr = IPAddr.new("192.168.1.50")
        #   ip_list = ["192.168.1.50", "10.0.0.1"]
        #   ip_matches_list?(client_addr, ip_list)
        #   # => true
        #
        # @example Matching CIDR range
        #   client_addr = IPAddr.new("192.168.1.50")
        #   ip_list = ["192.168.1.0/24", "10.0.0.0/8"]
        #   ip_matches_list?(client_addr, ip_list)
        #   # => true
        #
        # @example No match found
        #   client_addr = IPAddr.new("203.0.113.45")
        #   ip_list = ["192.168.1.0/24", "10.0.0.0/8"]
        #   ip_matches_list?(client_addr, ip_list)
        #   # => false
        #
        # @note Invalid IP patterns in the list are silently skipped
        # @note Supports both IPv4 and IPv6 addresses and ranges
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
