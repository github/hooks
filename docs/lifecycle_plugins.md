# Lifecycle Plugins

Lifecycle plugins allow you to hook into webhook request processing at three key points in the request lifecycle. This enables you to add custom functionality like metrics collection, error reporting, request logging, and more.

## Overview

The webhook processing lifecycle provides three hooks:

- **`on_request`**: Called before handler execution with request environment data
- **`on_response`**: Called after successful handler execution with response data
- **`on_error`**: Called when any error occurs during request processing

All lifecycle plugins have access to the global `stats` and `failbot` instruments for metrics and error reporting.

## Creating a Lifecycle Plugin

All lifecycle plugins must inherit from `Hooks::Plugins::Lifecycle` and can implement any or all of the lifecycle methods:

```ruby
class MetricsLifecycle < Hooks::Plugins::Lifecycle
  def on_request(env)
    # Called before handler execution
    # env contains Rack environment with request details
    stats.increment("webhook.requests", { 
      path: env["PATH_INFO"],
      method: env["REQUEST_METHOD"] 
    })
    
    log.info "Processing webhook request: #{env['REQUEST_METHOD']} #{env['PATH_INFO']}"
  end
  
  def on_response(env, response)
    # Called after successful handler execution
    # env contains the request environment
    # response contains the handler's response data
    stats.timing("webhook.response_time", env["hooks.processing_time"] || 0)
    
    log.info "Webhook processed successfully: #{response.inspect}"
  end
  
  def on_error(exception, env)
    # Called when any error occurs during request processing
    # exception is the error that occurred
    # env contains the request environment
    failbot.report(exception, { 
      path: env["PATH_INFO"],
      handler: env["hooks.handler"],
      method: env["REQUEST_METHOD"]
    })
    
    log.error "Webhook processing failed: #{exception.message}"
  end
end
```

## Available Data

### Request Environment (`env`)

The environment hash contains standard Rack environment variables plus webhook-specific data:

```ruby
{
  "REQUEST_METHOD" => "POST",
  "PATH_INFO" => "/webhook/my-endpoint",
  "HTTP_X_GITHUB_EVENT" => "push",
  "HTTP_X_HUB_SIGNATURE_256" => "sha256=...",
  "hooks.handler" => "MyHandler",
  "hooks.config" => { ... },  # Endpoint configuration
  "hooks.payload" => { ... },  # Parsed webhook payload
  "hooks.headers" => { ... },  # Cleaned HTTP headers
  "hooks.processing_time" => 0.123  # Available in on_response
}
```

### Response Data

The response parameter in `on_response` contains the data returned by your handler:

```ruby
{
  status: "success",
  message: "Webhook processed",
  data: { ... }
}
```

## Global Components

Lifecycle plugins have access to global components for cross-cutting concerns:

### Logger (`log`)

```ruby
def on_request(env)
  log.debug("Request details: #{env.inspect}")
  log.info("Processing #{env['HTTP_X_GITHUB_EVENT']} event")
  log.warn("Missing expected header") unless env["HTTP_X_GITHUB_EVENT"]
  log.error("Critical validation failure")
end
```

### Stats (`stats`)

```ruby
def on_request(env)
  # Increment counters
  stats.increment("webhook.requests", { event: env["HTTP_X_GITHUB_EVENT"] })
  
  # Record values
  stats.record("webhook.payload_size", env["CONTENT_LENGTH"].to_i)
  
  # Measure execution time
  stats.measure("webhook.processing", { handler: env["hooks.handler"] }) do
    # Processing happens in the handler
  end
end

def on_response(env, response)
  # Record timing from environment
  stats.timing("webhook.duration", env["hooks.processing_time"])
end
```

### Failbot (`failbot`)

```ruby
def on_error(exception, env)
  # Report errors with context
  failbot.report(exception, {
    endpoint: env["PATH_INFO"],
    event_type: env["HTTP_X_GITHUB_EVENT"],
    handler: env["hooks.handler"]
  })
  
  # Report critical errors
  failbot.critical("Handler crashed", { handler: env["hooks.handler"] })
  
  # Report warnings
  failbot.warning("Slow webhook processing", { duration: env["hooks.processing_time"] })
end

def on_request(env)
  # Capture and report exceptions during processing
  failbot.capture({ context: "request_validation" }) do
    validate_webhook_signature(env)
  end
end
```

## Configuration

To use custom lifecycle plugins, specify the `lifecycle_plugin_dir` in your configuration:

```yaml
# hooks.yml
lifecycle_plugin_dir: ./plugins/lifecycle
handler_plugin_dir: ./plugins/handlers
auth_plugin_dir: ./plugins/auth
```

Place your lifecycle plugin files in the specified directory:

```
plugins/
└── lifecycle/
    ├── metrics_lifecycle.rb
    ├── audit_lifecycle.rb
    └── performance_lifecycle.rb
```

## File Naming

Plugin files should be named using snake_case and the class name should be PascalCase:

- `metrics_lifecycle.rb` → `MetricsLifecycle`
- `audit_lifecycle.rb` → `AuditLifecycle`
- `performance_lifecycle.rb` → `PerformanceLifecycle`

## Example: Complete Monitoring Plugin

```ruby
class MonitoringLifecycle < Hooks::Plugins::Lifecycle
  def on_request(env)
    # Record request metrics
    stats.increment("webhook.requests.total", {
      method: env["REQUEST_METHOD"],
      path: env["PATH_INFO"],
      event: env["HTTP_X_GITHUB_EVENT"] || "unknown"
    })
    
    # Log request start
    log.info("Webhook request started", {
      method: env["REQUEST_METHOD"],
      path: env["PATH_INFO"],
      user_agent: env["HTTP_USER_AGENT"],
      content_length: env["CONTENT_LENGTH"]
    })
  end
  
  def on_response(env, response)
    # Record successful processing
    stats.increment("webhook.requests.success", {
      handler: env["hooks.handler"],
      event: env["HTTP_X_GITHUB_EVENT"]
    })
    
    # Record processing time
    if env["hooks.processing_time"]
      stats.timing("webhook.processing_time", env["hooks.processing_time"], {
        handler: env["hooks.handler"]
      })
    end
    
    log.info("Webhook request completed successfully", {
      handler: env["hooks.handler"],
      response_type: response.class.name,
      processing_time: env["hooks.processing_time"]
    })
  end
  
  def on_error(exception, env)
    # Record error metrics
    stats.increment("webhook.requests.error", {
      handler: env["hooks.handler"],
      error_type: exception.class.name,
      event: env["HTTP_X_GITHUB_EVENT"]
    })
    
    # Report error with full context
    failbot.report(exception, {
      handler: env["hooks.handler"],
      method: env["REQUEST_METHOD"],
      path: env["PATH_INFO"],
      event: env["HTTP_X_GITHUB_EVENT"],
      user_agent: env["HTTP_USER_AGENT"],
      content_length: env["CONTENT_LENGTH"]
    })
    
    log.error("Webhook request failed", {
      error: exception.message,
      handler: env["hooks.handler"],
      path: env["PATH_INFO"]
    })
  end
end
```

## Best Practices

1. **Keep lifecycle methods fast**: Avoid slow operations that could impact webhook processing performance
2. **Handle errors gracefully**: Lifecycle plugins should not cause webhook processing to fail
3. **Use appropriate log levels**: Debug for detailed info, info for normal flow, warn for issues, error for failures
4. **Include relevant context**: Add useful tags and context to metrics and error reports
5. **Test thoroughly**: Lifecycle plugins run for every webhook request, so bugs have high impact