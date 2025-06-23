# frozen_string_literal: true

module Hooks
  module Core
    # Shared module providing access to global components (logger, stats, failbot, and user-defined components)
    #
    # This module provides a consistent interface for accessing global components
    # across all plugin types, eliminating code duplication and ensuring consistent
    # behavior throughout the application.
    #
    # In addition to built-in components (log, stats, failbot), this module provides
    # dynamic access to any user-defined components passed to Hooks.build().
    #
    # @example Usage in a class that needs instance methods
    #   class MyHandler
    #     include Hooks::Core::ComponentAccess
    #
    #     def process
    #       log.info("Processing request")
    #       stats.increment("requests.processed")
    #       failbot.report("Error occurred") if error?
    #     end
    #   end
    #
    # @example Usage in a class that needs class methods
    #   class MyValidator
    #     extend Hooks::Core::ComponentAccess
    #
    #     def self.validate
    #       log.info("Validating request")
    #       stats.increment("requests.validated")
    #     end
    #   end
    #
    # @example Using user-defined components
    #   # Application setup
    #   publisher = KafkaPublisher.new
    #   email_service = EmailService.new
    #   app = Hooks.build(
    #     config: "config.yaml",
    #     publisher: publisher,
    #     email_service: email_service
    #   )
    #
    #   # Handler implementation
    #   class WebhookHandler < Hooks::Plugins::Handlers::Base
    #     include Hooks::Core::ComponentAccess
    #
    #     def call(payload:, headers:, env:, config:)
    #       # Use built-in components
    #       log.info("Processing webhook")
    #       stats.increment("webhooks.received")
    #
    #       # Use user-defined components
    #       publisher.send_message(payload, topic: "webhooks")
    #       email_service.send_notification(payload['email'], "Webhook processed")
    #
    #       { status: "success" }
    #     end
    #   end
    module ComponentAccess
      # Short logger accessor
      # @return [Hooks::Log] Logger instance for logging messages
      #
      # Provides a convenient way to log messages without needing
      # to reference the full Hooks::Log namespace.
      #
      # @example Logging an error
      #   log.error("Something went wrong")
      def log
        Hooks::Log.instance
      end

      # Global stats component accessor
      # @return [Hooks::Plugins::Instruments::Stats] Stats instance for metrics reporting
      #
      # Provides access to the global stats component for reporting metrics
      # to services like DataDog, New Relic, etc.
      #
      # @example Recording a metric
      #   stats.increment("webhook.processed", { handler: "MyHandler" })
      def stats
        Hooks::Core::GlobalComponents.stats
      end

      # Global failbot component accessor
      # @return [Hooks::Plugins::Instruments::Failbot] Failbot instance for error reporting
      #
      # Provides access to the global failbot component for reporting errors
      # to services like Sentry, Rollbar, etc.
      #
      # @example Reporting an error
      #   failbot.report("Something went wrong", { context: "additional info" })
      def failbot
        Hooks::Core::GlobalComponents.failbot
      end

      # Dynamic method access for user-defined components
      #
      # This method enables handlers to call user-defined components as methods.
      # For example, if a user registers a 'publisher' component, handlers can
      # call `publisher` or `publisher.some_method` directly.
      #
      # The method supports multiple usage patterns:
      # - Direct access: Returns the component instance for further method calls
      # - Callable access: If the component responds to #call, invokes it with provided arguments
      # - Method chaining: Allows fluent interface patterns with registered components
      #
      # @param method_name [Symbol] The method name being called
      # @param args [Array] Arguments passed to the method
      # @param kwargs [Hash] Keyword arguments passed to the method
      # @param block [Proc] Block passed to the method
      # @return [Object] The user component or result of method call
      # @raise [NoMethodError] If component doesn't exist and no super method available
      #
      # @example Accessing a publisher component directly
      #   # Given: Hooks.build(publisher: MyKafkaPublisher.new)
      #   class MyHandler < Hooks::Plugins::Handlers::Base
      #     def call(payload:, headers:, env:, config:)
      #       publisher.send_message(payload, topic: "webhooks")
      #       { status: "published" }
      #     end
      #   end
      #
      # @example Using a callable component (Proc/Lambda)
      #   # Given: Hooks.build(notifier: ->(msg) { puts "Notification: #{msg}" })
      #   class MyHandler < Hooks::Plugins::Handlers::Base
      #     def call(payload:, headers:, env:, config:)
      #       notifier.call("New webhook received")
      #       # Or use the shorthand syntax:
      #       notifier("Processing webhook for #{payload['user_id']}")
      #       { status: "notified" }
      #     end
      #   end
      #
      # @example Using a service object
      #   # Given: Hooks.build(email_service: EmailService.new(api_key: "..."))
      #   class MyHandler < Hooks::Plugins::Handlers::Base
      #     def call(payload:, headers:, env:, config:)
      #       email_service.send_notification(
      #         to: payload['email'],
      #         subject: "Webhook Processed",
      #         body: "Your webhook has been successfully processed"
      #       )
      #       { status: "email_sent" }
      #     end
      #   end
      #
      # @example Passing blocks to components
      #   # Given: Hooks.build(batch_processor: BatchProcessor.new)
      #   class MyHandler < Hooks::Plugins::Handlers::Base
      #     def call(payload:, headers:, env:, config:)
      #       batch_processor.process_with_callback(payload) do |result|
      #         log.info("Batch processing completed: #{result}")
      #       end
      #       { status: "batch_queued" }
      #     end
      #   end
      def method_missing(method_name, *args, **kwargs, &block)
        component = Hooks::Core::GlobalComponents.get_extra_component(method_name)

        if component
          # If called with arguments or block, try to call the component as a method
          if args.any? || kwargs.any? || block
            component.call(*args, **kwargs, &block)
          else
            # Otherwise return the component itself
            component
          end
        else
          # Fall back to normal method_missing behavior
          super
        end
      end

      # Respond to user-defined component names
      #
      # This method ensures that handlers properly respond to user-defined component
      # names, enabling proper method introspection and duck typing support.
      #
      # @param method_name [Symbol] The method name being checked
      # @param include_private [Boolean] Whether to include private methods
      # @return [Boolean] True if method exists or is a user component
      #
      # @example Checking if a component is available
      #   class MyHandler < Hooks::Plugins::Handlers::Base
      #     def call(payload:, headers:, env:, config:)
      #       if respond_to?(:publisher)
      #         publisher.send_message(payload)
      #         { status: "published" }
      #       else
      #         log.warn("Publisher not available, skipping message send")
      #         { status: "skipped" }
      #       end
      #     end
      #   end
      #
      # @example Conditional component usage
      #   class MyHandler < Hooks::Plugins::Handlers::Base
      #     def call(payload:, headers:, env:, config:)
      #       results = { status: "processed" }
      #
      #       # Only use analytics if available
      #       if respond_to?(:analytics)
      #         analytics.track_event("webhook_processed", payload)
      #         results[:analytics] = "tracked"
      #       end
      #
      #       # Only send notifications if notifier is available
      #       if respond_to?(:notifier)
      #         notifier.call("Webhook processed: #{payload['id']}")
      #         results[:notification] = "sent"
      #       end
      #
      #       results
      #     end
      #   end
      def respond_to_missing?(method_name, include_private = false)
        Hooks::Core::GlobalComponents.extra_component_exists?(method_name) || super
      end
    end
  end
end
