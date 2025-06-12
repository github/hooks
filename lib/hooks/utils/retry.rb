# frozen_string_literal: true

require "retryable"

# Utility module for retry functionality
module Retry
  # This method should be called as early as possible in the startup of your application
  # It sets up the Retryable gem with custom contexts and passes through a few options
  # Should the number of retries be reached without success, the last exception will be raised
  #
  # @param log [Logger] The logger to use for retryable logging
  # @raise [ArgumentError] If no logger is provided
  # @return [void]
  def self.setup!(log: nil, log_retries: ENV.fetch("RETRY_LOG_RETRIES", "true") == "true")
    raise ArgumentError, "a logger must be provided" if log.nil?

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
        sleep: ENV.fetch("DEFAULT_RETRY_SLEEP", "1").to_i,
        tries: ENV.fetch("DEFAULT_RETRY_TRIES", "10").to_i,
        log_method:
      }
    end
  end
end
