# frozen_string_literal: true

require "time"

module Hooks
  module Plugins
    module Auth
      # Validates and parses timestamps for webhook authentication
      #
      # This class provides secure timestamp validation supporting both
      # ISO 8601 UTC format and Unix timestamp format. It includes
      # strict validation to prevent various injection attacks.
      #
      # @example Basic usage
      #   validator = TimestampValidator.new
      #   validator.valid?("1609459200", 300)  # => true/false
      #   validator.parse("2021-01-01T00:00:00Z")  # => 1609459200
      #
      # @api private
      class TimestampValidator
        # Validate timestamp against current time with tolerance
        #
        # @param timestamp_value [String] The timestamp string to validate
        # @param tolerance [Integer] Maximum age in seconds (default: 300)
        # @return [Boolean] true if timestamp is valid and within tolerance
        def valid?(timestamp_value, tolerance = 300)
          return false if timestamp_value.nil? || timestamp_value.strip.empty?

          parsed_timestamp = parse(timestamp_value.strip)
          return false unless parsed_timestamp.is_a?(Integer)

          now = Time.now.utc.to_i
          (now - parsed_timestamp).abs <= tolerance
        end

        # Parse timestamp value supporting both ISO 8601 UTC and Unix formats
        #
        # @param timestamp_value [String] The timestamp string to parse
        # @return [Integer, nil] Epoch seconds if parsing succeeds, nil otherwise
        # @note Security: Strict validation prevents various injection attacks
        def parse(timestamp_value)
          return nil if invalid_characters?(timestamp_value)

          parse_iso8601_timestamp(timestamp_value) || parse_unix_timestamp(timestamp_value)
        end

        private

        # Check for control characters, whitespace, or null bytes
        #
        # @param timestamp_value [String] The timestamp to check
        # @return [Boolean] true if contains invalid characters
        def invalid_characters?(timestamp_value)
          if timestamp_value =~ /[\u0000-\u001F\u007F-\u009F]/
            log_warning("Timestamp contains invalid characters")
            true
          else
            false
          end
        end

        # Parse ISO 8601 UTC timestamp string (must have UTC indicator)
        #
        # @param timestamp_value [String] ISO 8601 timestamp string
        # @return [Integer, nil] Epoch seconds if parsing succeeds, nil otherwise
        def parse_iso8601_timestamp(timestamp_value)
          # Handle space-separated format and convert to standard ISO format
          if timestamp_value =~ /\A(\d{4}-\d{2}-\d{2}) (\d{2}:\d{2}:\d{2}(?:\.\d+)?)(?: )\+0000\z/
            timestamp_value = "#{$1}T#{$2}+00:00"
          end

          # Ensure the timestamp explicitly includes a UTC indicator
          return nil unless timestamp_value =~ /(Z|\+00:00|\+0000)\z/
          return nil unless iso8601_format?(timestamp_value)

          parsed_time = parse_time_safely(timestamp_value)
          return nil unless parsed_time&.utc_offset&.zero?

          parsed_time.to_i
        end

        # Parse Unix timestamp string (must be positive integer, no leading zeros except for "0")
        #
        # @param timestamp_value [String] Unix timestamp string
        # @return [Integer, nil] Epoch seconds if parsing succeeds, nil otherwise
        def parse_unix_timestamp(timestamp_value)
          return nil unless unix_format?(timestamp_value)

          ts = timestamp_value.to_i
          return nil if ts <= 0

          ts
        end

        # Check if timestamp string looks like ISO 8601 format
        #
        # @param timestamp_value [String] The timestamp string to check
        # @return [Boolean] true if it appears to be ISO 8601 format
        def iso8601_format?(timestamp_value)
          !!(timestamp_value =~ /\A\d{4}-\d{2}-\d{2}[T ]\d{2}:\d{2}:\d{2}(?:\.\d+)?(Z|\+00:00|\+0000)?\z/)
        end

        # Check if timestamp string looks like Unix timestamp format
        #
        # @param timestamp_value [String] The timestamp string to check
        # @return [Boolean] true if it appears to be Unix timestamp format
        def unix_format?(timestamp_value)
          return true if timestamp_value == "0"
          !!(timestamp_value =~ /\A[1-9]\d*\z/)
        end

        # Safely parse time string with error handling
        #
        # @param timestamp_value [String] The timestamp string to parse
        # @return [Time, nil] Parsed time object or nil if parsing fails
        def parse_time_safely(timestamp_value)
          Time.parse(timestamp_value)
        rescue ArgumentError
          nil
        end

        # Log warning message
        #
        # @param message [String] Warning message to log
        def log_warning(message)
          return unless defined?(Hooks::Log) && Hooks::Log.instance

          Hooks::Log.instance.warn("Auth::TimestampValidator validation failed: #{message}")
        end
      end
    end
  end
end
