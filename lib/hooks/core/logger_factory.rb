# frozen_string_literal: true

require "logger"
require "json"
require "securerandom"

module Hooks
  module Core
    # Factory for creating structured JSON loggers
    class LoggerFactory
      # Create a structured JSON logger
      #
      # @param log_level [String] Log level (debug, info, warn, error)
      # @param custom_logger [Logger] Custom logger instance (optional)
      # @return [Logger] Configured logger instance
      def self.create(log_level: "info", custom_logger: nil)
        return custom_logger if custom_logger

        logger = Logger.new($stdout)
        logger.level = parse_log_level(log_level)
        logger.formatter = json_formatter
        logger
      end

      private

      # Parse string log level to Logger constant
      #
      # @param level [String] Log level string
      # @return [Integer] Logger level constant
      def self.parse_log_level(level)
        case level.to_s.downcase
        when "debug" then Logger::DEBUG
        when "info" then Logger::INFO
        when "warn" then Logger::WARN
        when "error" then Logger::ERROR
        else Logger::INFO
        end
      end

      # JSON formatter for structured logging
      #
      # @return [Proc] Formatter procedure
      def self.json_formatter
        proc do |severity, datetime, progname, msg|
          log_entry = {
            timestamp: datetime.iso8601,
            level: severity.downcase,
            message: msg
          }

          # Add request context if available in thread local storage
          if Thread.current[:hooks_request_context]
            log_entry.merge!(Thread.current[:hooks_request_context])
          end

          "#{log_entry.to_json}\n"
        end
      end
    end

    # Helper for setting request context in logs
    module LogContext
      # Set request context for current thread
      #
      # @param context [Hash] Request context data
      def self.set(context)
        Thread.current[:hooks_request_context] = context
      end

      # Clear request context for current thread
      def self.clear
        Thread.current[:hooks_request_context] = nil
      end

      # Execute block with request context
      #
      # @param context [Hash] Request context data
      # @yield Block to execute with context
      def self.with(context)
        old_context = Thread.current[:hooks_request_context]
        Thread.current[:hooks_request_context] = context
        yield
      ensure
        Thread.current[:hooks_request_context] = old_context
      end
    end
  end
end
