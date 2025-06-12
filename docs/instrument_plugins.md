# Instrument Plugins

Instrument plugins provide global components for cross-cutting concerns like metrics collection and error reporting. The hooks framework includes two built-in instrument types: `stats` for metrics and `failbot` for error reporting. By default, these instruments are no-op implementations that do not require any external dependencies. You can create custom implementations to integrate with your preferred monitoring and error reporting services.

## Overview

By default, the framework provides no-op stub implementations that do nothing. This allows you to write code that calls instrument methods without requiring external dependencies. You can replace these stubs with real implementations that integrate with your monitoring and error reporting services.

The instrument plugins are accessible throughout the entire application:

- In handlers via `stats` and `failbot` methods
- In auth plugins via `stats` and `failbot` class methods  
- In lifecycle plugins via `stats` and `failbot` methods

## Creating Custom Instruments

To create custom instrument implementations, inherit from the appropriate base class and implement the required methods.

To actually have `stats` and `failbot` do something useful, you need to create custom classes that inherit from the base classes provided by the framework. Here’s an example of how to implement custom stats and failbot plugins.

You would then set the following attribute in your `hooks.yml` configuration file to point to these custom instrument plugins:

```yaml
# hooks.yml
instruments_plugin_dir: ./plugins/instruments
```

### Custom Stats Implementation

```ruby
# plugins/instruments/stats.rb
class Stats < Hooks::Plugins::Instruments::StatsBase
  def initialize
    # Initialize your metrics client
    @client = MyMetricsService.new(
      api_key: ENV["METRICS_API_KEY"],
      namespace: "webhooks"
    )
  end

  def record(metric_name, value, tags = {})
    @client.gauge(metric_name, value, tags: tags)
  rescue => e
    log.error("Failed to record metric: #{e.message}")
  end

  def increment(metric_name, tags = {})
    @client.increment(metric_name, tags: tags)
  rescue => e
    log.error("Failed to increment metric: #{e.message}")
  end

  def timing(metric_name, duration, tags = {})
    # Convert to milliseconds if your service expects that
    duration_ms = (duration * 1000).round
    @client.timing(metric_name, duration_ms, tags: tags)
  rescue => e
    log.error("Failed to record timing: #{e.message}")
  end

  # Optional: Add custom methods specific to your service
  def histogram(metric_name, value, tags = {})
    @client.histogram(metric_name, value, tags: tags)
  rescue => e
    log.error("Failed to record histogram: #{e.message}")
  end
end
```

### Custom Failbot Implementation

```ruby
# plugins/instruments/failbot.rb  
class Failbot < Hooks::Plugins::Instruments::FailbotBase
  def initialize
    # Initialize your error reporting client
    @client = MyErrorService.new(
      api_key: ENV["ERROR_REPORTING_API_KEY"],
      environment: ENV["RAILS_ENV"] || "production"
    )
  end

  def report(error_or_message, context = {})
    if error_or_message.is_a?(Exception)
      @client.report_exception(error_or_message, context)
    else
      @client.report_message(error_or_message, context)
    end
  rescue => e
    log.error("Failed to report error: #{e.message}")
  end

  def critical(error_or_message, context = {})
    enhanced_context = context.merge(severity: "critical")
    report(error_or_message, enhanced_context)
  end

  def warning(message, context = {})
    enhanced_context = context.merge(severity: "warning")
    @client.report_message(message, enhanced_context)
  rescue => e
    log.error("Failed to report warning: #{e.message}")
  end

  # Optional: Add custom methods specific to your service
  def set_user_context(user_id:, email: nil)
    @client.set_user_context(user_id: user_id, email: email)
  rescue => e
    log.error("Failed to set user context: #{e.message}")
  end

  def add_breadcrumb(message, category: "webhook", data: {})
    @client.add_breadcrumb(message, category: category, data: data)
  rescue => e
    log.error("Failed to add breadcrumb: #{e.message}")
  end
end
```

## Configuration

To use custom instrument plugins, specify the `instruments_plugin_dir` in your configuration:

```yaml
# hooks.yml
instruments_plugin_dir: ./plugins/instruments
handler_plugin_dir: ./plugins/handlers
auth_plugin_dir: ./plugins/auth
lifecycle_plugin_dir: ./plugins/lifecycle
```

Place your instrument plugin files in the specified directory:

```text
plugins/
└── instruments/
    ├── stats.rb
    └── failbot.rb
```

## File Naming and Class Detection

The framework automatically detects which type of instrument you're creating based on inheritance:

- Classes inheriting from `StatsBase` become the `stats` instrument
- Classes inheriting from `FailbotBase` become the `failbot` instrument

File naming follows snake_case to PascalCase conversion:

- `stats.rb` → `stats`
- `sentry_failbot.rb` → `SentryFailbot`

You can only have one `stats` plugin and one `failbot` plugin loaded. If multiple plugins of the same type are found, the last one loaded will be used.

## Usage in Your Code

Once configured, your custom instruments are available throughout the application:

### In Handlers

```ruby
class MyHandler < Hooks::Plugins::Handlers::Base
  def call(payload:, headers:, config:)
    # Use your custom stats methods
    stats.increment("handler.calls", { handler: "MyHandler" })
    
    # Use custom methods if you added them
    stats.histogram("payload.size", payload.to_s.length) if stats.respond_to?(:histogram)
    
    result = stats.measure("handler.processing", { handler: "MyHandler" }) do
      process_webhook(payload, headers, config)
    end
    
    # Use your custom failbot methods
    failbot.add_breadcrumb("Handler completed successfully") if failbot.respond_to?(:add_breadcrumb)
    
    result
  rescue => e
    failbot.report(e, { handler: "MyHandler", event: headers["x-github-event"] })
    raise
  end
end
```

### In Lifecycle Plugins

```ruby
class MetricsLifecycle < Hooks::Plugins::Lifecycle
  def on_request(env)
    # Your custom stats implementation will be used
    stats.increment("requests.total", { 
      path: env["PATH_INFO"],
      method: env["REQUEST_METHOD"]
    })
  end
  
  def on_error(exception, env)
    # Your custom failbot implementation will be used
    failbot.report(exception, {
      path: env["PATH_INFO"],
      handler: env["hooks.handler"]
    })
  end
end
```

## Popular Integrations

### DataDog Stats

```ruby
class DatadogStats < Hooks::Plugins::Instruments::StatsBase
  def initialize
    require "datadog/statsd"
    @statsd = Datadog::Statsd.new("localhost", 8125, namespace: "webhooks")
  end

  def record(metric_name, value, tags = {})
    @statsd.gauge(metric_name, value, tags: format_tags(tags))
  end

  def increment(metric_name, tags = {})
    @statsd.increment(metric_name, tags: format_tags(tags))
  end

  def timing(metric_name, duration, tags = {})
    @statsd.timing(metric_name, duration, tags: format_tags(tags))
  end

  private

  def format_tags(tags)
    tags.map { |k, v| "#{k}:#{v}" }
  end
end
```

### Sentry Failbot

```ruby
class SentryFailbot < Hooks::Plugins::Instruments::FailbotBase
  def initialize
    require "sentry-ruby"
    Sentry.init do |config|
      config.dsn = ENV["SENTRY_DSN"]
      config.environment = ENV["RAILS_ENV"] || "production"
    end
  end

  def report(error_or_message, context = {})
    Sentry.with_scope do |scope|
      context.each { |key, value| scope.set_context(key, value) }
      
      if error_or_message.is_a?(Exception)
        Sentry.capture_exception(error_or_message)
      else
        Sentry.capture_message(error_or_message)
      end
    end
  end

  def critical(error_or_message, context = {})
    Sentry.with_scope do |scope|
      scope.set_level(:fatal)
      context.each { |key, value| scope.set_context(key, value) }
      
      if error_or_message.is_a?(Exception)
        Sentry.capture_exception(error_or_message)
      else
        Sentry.capture_message(error_or_message)
      end
    end
  end

  def warning(message, context = {})
    Sentry.with_scope do |scope|
      scope.set_level(:warning)
      context.each { |key, value| scope.set_context(key, value) }
      Sentry.capture_message(message)
    end
  end
end
```

## Testing Your Instruments

When testing, you may want to use test doubles or capture calls:

```ruby
# In your test setup
class TestStats < Hooks::Plugins::Instruments::StatsBase
  attr_reader :recorded_metrics

  def initialize
    @recorded_metrics = []
  end

  def record(metric_name, value, tags = {})
    @recorded_metrics << { type: :record, name: metric_name, value: value, tags: tags }
  end

  def increment(metric_name, tags = {})
    @recorded_metrics << { type: :increment, name: metric_name, tags: tags }
  end

  def timing(metric_name, duration, tags = {})
    @recorded_metrics << { type: :timing, name: metric_name, duration: duration, tags: tags }
  end
end

# Use in tests
test_stats = TestStats.new
Hooks::Core::GlobalComponents.stats = test_stats

# Your test code here

expect(test_stats.recorded_metrics).to include(
  { type: :increment, name: "webhook.processed", tags: { handler: "MyHandler" } }
)
```

## Best Practices

1. **Handle errors gracefully**: Instrument failures should not break webhook processing
2. **Use appropriate log levels**: Log instrument failures at error level  
3. **Add timeouts**: Network calls to external services should have reasonable timeouts
4. **Validate configuration**: Check for required environment variables in `initialize`
5. **Document custom methods**: If you add methods beyond the base interface, document them
6. **Consider performance**: Instruments are called frequently, so keep operations fast
7. **Use connection pooling**: For high-throughput scenarios, use connection pooling for external services
