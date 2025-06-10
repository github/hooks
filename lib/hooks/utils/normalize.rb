# frozen_string_literal: true

module Hooks
  module Utils
    # Utility class for normalizing HTTP headers
    #
    # Provides a robust method to consistently format HTTP headers
    # across the application, handling various edge cases and formats.
    class Normalize
      # Normalize a hash of HTTP headers
      #
      # @param headers [Hash, #each] Headers hash or hash-like object
      # @return [Hash] Normalized headers hash with downcased keys and trimmed values
      #
      # @example Hash of headers normalization
      #   headers = { "Content-Type" => "  application/json  ", "X-GitHub-Event" => "push" }
      #   normalized = Normalize.headers(headers)
      #   # => { "content-type" => "application/json", "x-github-event" => "push" }
      #
      # @example Handle various input types
      #   Normalize.headers(nil)                    # => nil
      #   Normalize.headers({})                     # => {}
      #   Normalize.headers({ "KEY" => ["a", "b"] }) # => { "key" => "a" }
      #   Normalize.headers({ "Key" => 123 })       # => { "key" => "123" }
      def self.headers(headers)
        # Handle nil input
        return nil if headers.nil?

        # Fast path for non-enumerable inputs (numbers, etc.)
        return {} unless headers.respond_to?(:each)

        normalized = {}

        headers.each do |key, value|
          # Skip nil keys or values entirely
          next if key.nil? || value.nil?

          # Convert key to string, downcase, and strip in one operation
          normalized_key = key.to_s.downcase.strip
          next if normalized_key.empty?

          # Handle different value types efficiently
          normalized_value = case value
                             when String
                               value.strip
                             when Array
                               # Take first non-empty element for multi-value headers
                               first_valid = value.find { |v| v && !v.to_s.strip.empty? }
                               first_valid ? first_valid.to_s.strip : nil
                             else
                               value.to_s.strip
                             end

          # Only add if we have a non-empty value
          normalized[normalized_key] = normalized_value if normalized_value && !normalized_value.empty?
        end

        normalized
      end

      # Normalize a single HTTP header name
      #
      # @param header [String] Header name to normalize
      # @return [String, nil] Normalized header name (downcased and trimmed), or nil if input is nil
      #
      # @example Single header normalization
      #   Normalize.header("  Content-Type  ")  # => "content-type"
      #   Normalize.header("X-GitHub-Event")    # => "x-github-event"
      #   Normalize.header("")                  # => ""
      #   Normalize.header(nil)                 # => nil
      #
      # @raise [ArgumentError] If input is not a String or nil
      def self.header(header)
        return nil if header.nil?
        if header.is_a?(String)
          header.downcase.strip
        else
          raise ArgumentError, "Expected a String for header normalization"
        end
      end
    end
  end
end
