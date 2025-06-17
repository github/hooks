# frozen_string_literal: true
# Example custom auth plugin for IP filtering
module Hooks
  module Plugins
    module Auth
      class IpFilteringExample < Base
        def self.valid?(payload:, headers:, config:)
          # Get the allowed IPs from the configuration (opts is a hash containing additional options that can be set in any endpoint configuration)
          allowed_ips = config.dig(:opts, :allowed_ips) || []

          # Get the request IP from headers or payload
          # Find the IP via the request headers with case-insensitive matching - this is a helper method available in the base class
          # so it is available to all auth plugins.
          # This example assumes the IP is in the "X-Forwarded-For" header, which is common for proxied requests
          request_ip = find_header_value(headers, "X-Forwarded-For")

          # If the request IP is not found, return false
          return false unless request_ip

          # Return true if the request IP is in the allowed IPs list
          allowed_ips.include?(request_ip)
        end
      end
    end
  end
end
