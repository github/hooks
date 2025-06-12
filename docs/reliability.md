# Production Reliability and Performance Guide

This document outlines the reliability, performance, and security considerations for running the Hooks webhook server framework in production environments.

## 🔍 Security Considerations

### Dynamic Plugin Loading Security

The framework includes comprehensive security measures for dynamic plugin loading:

- **Class Name Validation**: All plugin class names are validated against safe patterns (`/\A[A-Z][a-zA-Z0-9_]*\z/`)
- **Dangerous Class Blacklist**: System classes like `File`, `Dir`, `Kernel`, `Object`, `Process`, etc. are blocked from being loaded as plugins
- **Path Traversal Protection**: Plugin file paths are normalized and validated to prevent loading files outside designated directories
- **Safe Constant Resolution**: Uses `Object.const_get` only after thorough validation

### Request Processing Security

- **Request Size Limits**: Configurable request body size limits (default enforcement via `request_limit` config)
- **JSON Parsing Protection**: JSON parsing includes security limits to prevent JSON bombs:
  - Maximum nesting depth (configurable via `JSON_MAX_NESTING`, default: 20)
  - Maximum payload size before parsing (configurable via `JSON_MAX_SIZE`, default: 10MB)
  - Disabled object creation from JSON (`create_additions: false`)
  - Uses plain Hash/Array classes to prevent object injection
- **Header Validation**: Multiple header format handling with safe fallbacks and optimized lookup order

## ⚡ Performance Optimizations

### Startup Performance

The framework uses several strategies to optimize startup time:

- **Explicit Module Loading**: Core modules are loaded explicitly rather than using `Dir.glob` patterns for better performance and security
- **Boot-time Plugin Loading**: All plugins are loaded once at startup rather than per-request
- **Plugin Caching**: Loaded plugins are cached in class-level registries for fast access
- **Sorted Directory Loading**: Plugin directories are processed in sorted order for consistent behavior

### Runtime Performance

- **Per-request Optimizations**: 
  - Plugin instances are reused across requests
  - Request contexts use thread-local storage for efficient access
  - Handler instances are created per-request but classes are cached
  - Optimized header processing with common cases checked first

- **Memory Management**:
  - Plugin registries use hash-based lookups for O(1) access
  - Thread-local contexts are properly cleaned up after requests
  - Clear plugin loading separates concerns efficiently

- **Security Limits**:
  - Retry configuration includes bounds checking to prevent resource exhaustion
  - JSON parsing has built-in limits to prevent JSON bombs and memory attacks

### Recommended Production Configuration

```yaml
# Example production configuration
log_level: "info"              # Reduces debug overhead
request_limit: 1048576         # 1MB limit (adjust based on needs)
request_timeout: 30            # 30 second timeout
environment: "production"      # Disables debug features like backtraces
normalize_headers: true        # Consistent header processing
symbolize_payload: false       # Reduced memory usage for large payloads
```

### Security Environment Variables

Additional security can be configured via environment variables:

```bash
# JSON Security Limits
JSON_MAX_NESTING=20           # Maximum JSON nesting depth (default: 20)
JSON_MAX_SIZE=10485760        # Maximum JSON size before parsing (default: 10MB)

# Retry Safety Limits  
DEFAULT_RETRY_SLEEP=1         # Sleep between retries 0-300 seconds (default: 1)
DEFAULT_RETRY_TRIES=10        # Number of retry attempts 1-50 (default: 10)
RETRY_LOG_RETRIES=false       # Disable retry logging in production (default: true)
```

## 🔧 Monitoring and Observability

### Health Check Endpoint

The built-in health endpoint (`/health`) provides comprehensive status information:

```json
{
  "status": "healthy",
  "timestamp": "2025-01-01T12:00:00Z",
  "version": "1.0.0",
  "uptime_seconds": 3600,
  "config_checksum": "abc123",
  "endpoints_loaded": 5,
  "plugins_loaded": 3
}
```

### Lifecycle Hooks for Monitoring

Use lifecycle plugins to add comprehensive monitoring:

- **Request Metrics**: Track request counts, timing, and error rates
- **Error Reporting**: Capture and report exceptions with full context
- **Resource Monitoring**: Track memory usage, plugin load times, etc.

### Recommended Instrumentation

```ruby
# Example monitoring lifecycle plugin
class MonitoringLifecycle < Hooks::Plugins::Lifecycle
  def on_request(env)
    stats.increment("webhook.requests", {
      handler: env["hooks.handler"],
      endpoint: env["PATH_INFO"]
    })
  end

  def on_response(env, response)
    processing_time = Time.now - Time.parse(env["hooks.start_time"])
    stats.timing("webhook.processing_time", processing_time * 1000, {
      handler: env["hooks.handler"]
    })
  end

  def on_error(exception, env)
    stats.increment("webhook.errors", {
      error_type: exception.class.name,
      handler: env["hooks.handler"]
    })
    
    failbot.report(exception, {
      request_id: env["hooks.request_id"],
      handler: env["hooks.handler"],
      endpoint: env["PATH_INFO"]
    })
  end
end
```

## 🚀 Production Deployment Best Practices

### Server Configuration

1. **Use Puma in Cluster Mode** for production:
```ruby
# config/puma.rb
workers ENV.fetch("WEB_CONCURRENCY", 2)
threads_count = ENV.fetch("MAX_THREADS", 5)
threads threads_count, threads_count
preload_app!
```

2. **Configure Resource Limits**:
   - Set appropriate worker memory limits
   - Configure worker restart thresholds
   - Set connection pool sizes appropriately

3. **Environment Variables**:
```bash
# Retry configuration
DEFAULT_RETRY_TRIES=3          # Reduced from default 10
DEFAULT_RETRY_SLEEP=1          # 1 second between retries
RETRY_LOG_RETRIES=false        # Reduce log noise in production

# Logging
LOG_LEVEL=info                 # Reduce debug overhead
```

### Container Considerations

```dockerfile
# Optimized production Dockerfile
FROM ruby:3.2-alpine AS builder
WORKDIR /app
COPY Gemfile* ./
RUN bundle install --deployment --without development test

FROM ruby:3.2-alpine
WORKDIR /app
COPY --from=builder /app/vendor ./vendor
COPY . .

# Security: Run as non-root user
RUN addgroup -g 1001 -S appuser && \
    adduser -S appuser -u 1001 -G appuser
USER appuser

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
  CMD curl -f http://localhost:3000/health || exit 1

EXPOSE 3000
CMD ["bundle", "exec", "puma", "-C", "config/puma.rb"]
```

## 🛡️ Security Hardening

### Input Validation

- **Payload Size Limits**: Always configure `request_limit` appropriate for your use case
- **Timeout Configuration**: Set reasonable `request_timeout` values
- **Content Type Validation**: Implement strict content type checking if needed

### Authentication

- **HMAC Validation**: Always enable authentication for production endpoints
- **Secret Management**: Store webhook secrets in environment variables or secure secret management systems
- **Signature Validation**: Use time-based signature validation to prevent replay attacks

### Network Security

- **TLS Termination**: Always terminate TLS/SSL at load balancer or reverse proxy
- **IP Whitelisting**: Implement IP restrictions at network level when possible
- **Rate Limiting**: Implement rate limiting at reverse proxy/load balancer level

## 📊 Performance Benchmarking

### Load Testing Recommendations

1. **Baseline Testing**: Test with minimal handlers and no lifecycle plugins
2. **Plugin Impact**: Measure performance impact of each lifecycle plugin
3. **Memory Profiling**: Monitor memory usage over extended periods
4. **Concurrency Testing**: Test with realistic concurrent webhook loads

### Key Metrics to Monitor

- **Request Processing Time**: P50, P95, P99 response times
- **Memory Usage**: RSS, heap size, GC frequency
- **Error Rates**: 4xx and 5xx response rates
- **Plugin Performance**: Individual plugin execution times
- **Resource Utilization**: CPU, memory, network I/O

## 🔧 Troubleshooting

### Common Performance Issues

1. **High Memory Usage**:
   - Check for plugin memory leaks
   - Monitor payload sizes
   - Review lifecycle plugin efficiency

2. **Slow Request Processing**:
   - Profile individual plugins
   - Check JSON parsing performance
   - Review handler implementation efficiency

3. **Plugin Loading Issues**:
   - Verify plugin directory permissions
   - Check plugin class name formatting
   - Review security validation errors

### Debug Configuration

For troubleshooting, temporarily enable debug logging:

```yaml
log_level: "debug"
environment: "development"  # Enables error backtraces
```

**Important**: Never run production with debug logging enabled long-term due to performance and security implications.