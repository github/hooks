# frozen_string_literal: true

require "retryable"

# Utility module for retry functionality
module Retry
  # This method should be called as early as possible in the startup of your application
  # It sets up the Retryable gem with custom contexts and passes through a few options
  # Should the number of retries be reached without success, the last exception will be raised
  #
  # @param log [Logger] The logger to use for retryable logging
  # @raise [ArgumentError] If no logger is provided or configuration values are invalid
  # @return [void]
  def self.setup!(log: nil, log_retries: ENV.fetch("RETRY_LOG_RETRIES", "true") == "true")
    raise ArgumentError, "a logger must be provided" if log.nil?

    # Security: Validate and bound retry configuration values
    retry_sleep = ENV.fetch("DEFAULT_RETRY_SLEEP", "1").to_i
    retry_tries = ENV.fetch("DEFAULT_RETRY_TRIES", "10").to_i

    # Bounds checking to prevent resource exhaustion
    if retry_sleep < 0 || retry_sleep > 300  # Max 5 minutes between retries
      raise ArgumentError, "DEFAULT_RETRY_SLEEP must be between 0 and 300 seconds, got: #{retry_sleep}"
    end

    if retry_tries < 1 || retry_tries > 50   # Max 50 retries to prevent infinite loops
      raise ArgumentError, "DEFAULT_RETRY_TRIES must be between 1 and 50, got: #{retry_tries}"
    end

    log_method = lambda do |retries, exception|
      # :nocov:
      if log_retries
        log.debug("[retry ##{retries}] #{exception.class}: #{exception.message} - #{exception.backtrace.join("\n")}")
      end
      # :nocov:
    end

    ######## Retryable Configuration ########
    # All defaults available here:
    # https://github.com/nfedyashev/retryable/blob/6a04027e61607de559e15e48f281f3ccaa9750e8/lib/retryable/configuration.rb#L22-L33
    Retryable.configure do |config|
      config.contexts[:default] = {
        on: [StandardError],
        sleep: retry_sleep,
        tries: retry_tries,
        log_method:
      }
    end
  end
end
