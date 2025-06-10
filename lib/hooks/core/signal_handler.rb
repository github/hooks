# frozen_string_literal: true

module Hooks
  module Core
    # Handles graceful shutdown signals
    class SignalHandler
      # Initialize signal handler
      #
      # @param logger [Logger] Logger instance
      # @param graceful_timeout [Integer] Seconds to wait for graceful shutdown
      def initialize(logger, graceful_timeout: 30)
        @logger = logger
        @graceful_timeout = graceful_timeout
        @shutdown_requested = false
        # Don't setup signal traps - let Puma handle them
        # setup_signal_traps
      end

      # Check if shutdown has been requested
      #
      # @return [Boolean] true if shutdown requested
      def shutdown_requested?
        @shutdown_requested
      end

      # Manually request shutdown (for testing or programmatic shutdown)
      def request_shutdown
        @shutdown_requested = true
        @logger.info "Shutdown requested"
      end

      private

      # Setup signal traps for graceful shutdown
      # NOTE: Disabled for now to let Puma handle signals properly
      # :nocov:
      def setup_signal_traps
        %w[SIGINT SIGTERM].each do |signal|
          Signal.trap(signal) do
            # Don't use logger in signal trap - just set the flag
            unless @shutdown_requested
              @shutdown_requested = true

              # Use STDERR for immediate output since logger might not work in trap context
              $stderr.puts "Received #{signal}, initiating graceful shutdown (timeout: #{@graceful_timeout}s)"

              # Don't start a timeout thread - let Puma handle the shutdown
            end
          end
        end
      end
      # :nocov:
    end
  end
end
