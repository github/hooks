# `hooks` — A Pluggable Ruby Webhook Server Framework

## 📜 1. Project Overview

`hooks` is a **pure-Ruby**, **Grape-based**, **Rack-compatible** webhook server gem that:

* Dynamically mounts endpoints from per-team configs under a configurable `root_path`
* Loads **team handlers** and **global plugins** at boot
* Validates configs via **Dry::Schema**, failing fast on invalid YAML/JSON/Hash
* Supports **signature validation** (default HMAC) and **custom validator** classes
* Enforces **request limits** (body size) and **timeouts**, configurable at runtime
* Ships with operational endpoints:

  * **GET** `<health_path>`: liveness/readiness payload
  * **GET** `<version_path>`: current gem version

* Boots a demo `<root_path>/hello` route when no config is supplied, to verify setup

> **Server Agnostic:** `hooks` exports a Rack-compatible app. Mount under any Rack server (Puma, Unicorn, Thin, etc.).

Note: The `hooks` gem name is already taken on RubyGems, so this project is named `hooks-ruby` there.

---

## 🎯 2. Core Goals

1. **Config-Driven Endpoints**

   * Single file per endpoint: YAML, JSON, or Ruby Hash
   * Merged into `AppConfig` at boot, validated
   * Each endpoint `path` is prefixed by global `root_path` (default `/webhooks`)

2. **Plugin Architecture**

   * **Team Handlers**: `class MyHandler < Hooks::Handlers::Base`
     * Must implement `#call(payload:, headers:, config:)` method
     * `payload`: parsed request body (JSON Hash or raw String)
     * `headers`: HTTP headers as Hash with string keys
     * `config`: merged endpoint configuration including `opts` section
   * **Global Plugins**: `class MyPlugin < Hooks::Plugins::Lifecycle`
     * Hook methods: `#on_request`, `#on_response`, `#on_error`
   * **Signature Validators**: implement class method `.valid?(payload:, headers:, secret:, config:)`
     * Return `true`/`false` for signature validation
     * Access to full request context for custom validation logic

3. **Security & Isolation**

   * Default JSON error responses, with detailed hooks

4. **Operational Endpoints**

   * **Health**: liveness/readiness, config checksums
   * **Version**: gem version report

5. **Developer & Operator Experience**

   * Single entrypoint: `app = Hooks.build(...)`
   * Multiple configuration methods: path(s), ENV, Ruby Hash
   * Graceful shutdown on SIGINT/SIGTERM
   * Structured JSON logging with `request_id`, `path`, `handler`, timestamp
   * Scaffold generators for handlers and plugins

---

## ⚙️ 3. Installation & Invocation

### Gemfile

```ruby
gem "hooks-ruby"
```

### Programmatic Invocation

```ruby
require "hooks-ruby"

# Returns a Rack-compatible app
app = Hooks.build(
  config:           "/path/to/config.yaml",      # YAML, JSON, or Hash
  log:               MyCustomLogger.new,          # Optional logger (must respond to #info, #error, etc.)
  request_limit:     1_048_576,                   # Default max body size (bytes)
  request_timeout:   15,                          # Default timeout (seconds)
  root_path:        "/webhooks"                  # Default mount prefix
)
```

Mount in `config.ru`:

```ruby
run app
```

### ENV-Based Bootstrap

Core configuration options can be provided via environment variables:

```bash
# Core configuration
export HOOKS_CONFIG=./config/config.yaml

# Runtime settings (override config file)
export HOOKS_REQUEST_LIMIT=1048576
export HOOKS_REQUEST_TIMEOUT=15
export HOOKS_GRACEFUL_SHUTDOWN_TIMEOUT=30
export HOOKS_ROOT_PATH="/webhooks"

# Logging
export HOOKS_LOG_LEVEL=info

# Paths
export HOOKS_HANDLER_DIR=./handlers
export HOOKS_HEALTH_PATH=/health
export HOOKS_VERSION_PATH=/version

# Start the application
ruby -r hooks-ruby -e "run Hooks.build"
```

> **Hello-World Mode**
> If invoked without `config`, serves `GET <root_path>/hello`:
>
> ```json
> { "message": "Hooks is working!" }
> ```

---

## 📁 4. Directory Layout

```text
lib/hooks/
├── app/
│   ├── api.rb                # Grape::API subclass exporting all endpoints
│   ├── router_builder.rb     # Reads AppConfig to define routes
│   └── endpoint_builder.rb   # Wraps each route: auth, signature, hooks, handler
│
├── core/
│   ├── builder.rb            # Hooks.build: config loading, validation, signal handling - builds a rack compatible app
│   ├── config_loader.rb      # Loads + merges per-endpoint configs
│   ├── config_validator.rb   # Dry::Schema-based validation
│   ├── logger_factory.rb     # Structured JSON logger + context enrichment
│
├── handlers/
│   └── base.rb               # `Hooks::Handlers::Base` interface: defines #call
│
├── plugins/
│   ├── lifecycle.rb          # `Hooks::Plugins::Lifecycle` hooks (on_request, response, error)
│   └── signature_validator/  # Default & sample validators
│       ├── base.rb           # Abstract interface
│       └── hmac_sha256.rb    # Default implementation
│
├── version.rb                # Provides `Hooks::VERSION`
└── hooks.rb                  # `require 'hooks'` entrypoint defining Hooks module
```

---

## 🛠️ 5. Config Models

### 5.1 Endpoint Config (per-file)

```yaml
# config/endpoints/team1.yaml
path: /team1                  # Mounted at <root_path>/team1
handler: Team1Handler         # Class in handler_dir

# Signature validation
auth:
  type: default               # 'default' uses HMACSHA256, or a custom class name
  secret_env_key: TEAM1_SECRET
  header: X-Hub-Signature
  algorithm: sha256

opts:                         # Freeform user-defined options
  env: staging
  teams: ["infra","billing"]
```

### 5.2 Global Config File

```yaml
# config/config.yaml
handler_dir:     ./handlers         # handler class directory
log_level:       info               # debug | info | warn | error

# Request handling
request_limit:   1048576            # max request body size (bytes)
request_timeout: 15                 # seconds to allow per request

# Path configuration
root_path:       /webhooks          # base path for all endpoint routes
health_path:     /health            # operational health endpoint
version_path:    /version           # gem version endpoint

# Runtime behavior
environment:     production         # development | production
endpoints_dir:   ./config/endpoints # directory containing endpoint configs
```

---

## 🔍 6. Core Components & Flow

1. **Builder (`core/builder.rb`)**

   * Load config (env or file) via `config_loader`
   * Load endpoint configs via `config_loader`
   * Validate via `config_validator` (Dry::Schema); halt if invalid at boot
   * Initialize structured JSON logger via `logger_factory`
   * Emit startup `:request_start` for `/health` and `/version`
   * Trap SIGINT/SIGTERM for graceful shutdown
   * Build and return Rack app from `app/api.rb`

2. **API Definition (`app/api.rb`)**

   * Uses Grape::API
   * Mounts:

     * `<root_path>/hello` (demo)
     * `<health_path>` and `<version_path>`
     * Each team endpoint under `<root_path>/<path>`

3. **Router & Endpoint Builder**

   * For each endpoint config:

     * Define Grape route with:

       * **Before**: enforce `request_limit`, `request_timeout`
       * **Signature**: call custom or default validator
       * **Hooks**: run `on_request` plugins
     * **Handler**: invoke `MyHandler.new.call(payload:, headers:, config:)`
     * **After**: run `on_response` plugins
     * **Rescue**: on exception, run `on_error`, rethrow or format JSON error

4. **Graceful Shutdown**

   * On SIGINT/SIGTERM: allow in-flight requests to finish, exit

---

## 🔒 7. Security & Isolation

* **Request Validation**: size, timeout, signature enforced systematically
* **Error Handling**: exceptions bubble to Grape catchall, with JSON schema

---

## 🚨 8. Error Handling & Logging

### Error Response Format

**Default JSON Error Response:**

```json
{
  "error": "Error message",
  "code": 500,
  "request_id": "uuid-string"
}
```

**Environment-specific behavior:**

* **Development Mode**: includes full stack trace in `backtrace` field
* **Production Mode**: hides sensitive details, logs full context internally

### Custom Error Handling

Users can customize error responses via global plugins:

```ruby
class CustomErrorPlugin < Hooks::Plugins::Lifecycle
  def on_error(exception, env)
    # Custom error processing, logging, or response formatting
    {
      error: "Custom error message",
      code: determine_error_code(exception),
      timestamp: Time.now.iso8601
    }
  end
end
```

### Structured Logging

Each log entry includes standardized fields:

* `timestamp` (ISO8601)
* `level` (debug, info, warn, error)
* `message`
* `request_id` (UUID for request correlation)
* `path` (endpoint path)
* `handler` (handler class name)
* `status` (HTTP status code)
* `duration_ms` (request processing time)
* `user_agent`, `remote_ip` (when available)

---

## 📈 9. Instrumentation

Simple request logging for basic observability:

* Basic request/response logging with timestamps
* Simple error tracking
* Basic health check endpoint returning service status

**Example log output:**

```json
{
  "timestamp": "2025-06-09T10:30:00Z",
  "level": "info",
  "message": "Request processed",
  "request_id": "uuid-string",
  "path": "/webhooks/team1",
  "handler": "Team1Handler",
  "status": 200,
  "duration_ms": 45
}
```

---

## ⚡ 10. Configuration Loading & Precedence

Configuration is loaded and merged in the following priority order (highest to lowest):

1. **Programmatic parameters** passed to `Hooks.build(...)`
2. **Environment variables** (`HOOKS_*`)
3. **Config file** (YAML/JSON)
4. **Built-in defaults**

**Example:**

```ruby
# This programmatic setting will override ENV and file settings
app = Hooks.build(
  request_timeout: 30,  # Overrides HOOKS_REQUEST_TIMEOUT and config.yaml
  config: "./config/config.yaml"
)
```

**Handler & Plugin Discovery:**

* Handler classes are auto-discovered from `handler_dir` using file naming convention
* File `team1_handler.rb` → class `Team1Handler`
* Plugin classes are loaded from `plugin_dir` and registered based on class inheritance
* All classes must inherit from appropriate base classes to be recognized

---

## 🛠️ 11. CLI & Scaffolding

Command-line interface via `bin/hooks`:

```bash
# Create a new handler skeleton
hooks scaffold handler my_endpoint

# Create a new global plugin skeleton
hooks scaffold plugin my_plugin

# Validate existing configuration
hooks validate

# Show current configuration summary
hooks config
```

**Generated Files:**

* `handlers/my_endpoint_handler.rb` - Handler class skeleton
* `config/endpoints/my_endpoint.yaml` - Endpoint configuration template
* `plugins/my_plugin.rb` - Plugin class skeleton with lifecycle hooks

---

## 🖥️ 16. CLI Utility: `hooks serve`

The project provides a `hooks serve` command-line utility for running the webhook server directly, similar to `rails server`.

### Usage

```bash
hooks serve [options]
```

#### Common Options

* `-p`, `--port PORT` — Port to listen on (default: 3000)
* `-b`, `--bind HOST` — Bind address (default: 0.0.0.0)
* `-e`, `--env ENV` — Environment (default: production)
* `-c`, `--config PATH` — Path to config file (YAML/JSON)
* `--no-puma` — (Advanced) Use the default Rack handler instead of Puma
* `-h`, `--help` — Show help message

### Example

```bash
hooks serve -p 8080 -c ./config/config.yaml
```

### How it Works

* The CLI loads configuration from CLI args, ENV, or defaults.
* It builds the Rack app using `Hooks.build(...)`.
* By default, it starts the server using Puma (via `Rack::Handler::Puma`).
* If Puma is not available, it falls back to the default Rack handler (e.g., WEBrick), but Puma is strongly recommended and included as a dependency.

### Implementation Sketch

```ruby
# bin/hooks (excerpt)
require "hooks-ruby"
require "optparse"

options = {
  port: ENV.fetch("PORT", 3000),
  bind: ENV.fetch("BIND", "0.0.0.0"),
  env: ENV.fetch("RACK_ENV", "production"),
  config: ENV["HOOKS_CONFIG"] || "./config/config.yaml",
  use_puma: true
}

OptionParser.new do |opts|
  opts.banner = "Usage: hooks serve [options]"
  opts.on("-pPORT", "--port=PORT", Integer, "Port to listen on") { |v| options[:port] = v }
  opts.on("-bHOST", "--bind=HOST", String, "Bind address") { |v| options[:bind] = v }
  opts.on("-eENV", "--env=ENV", String, "Environment") { |v| options[:env] = v }
  opts.on("-cPATH", "--config=PATH", String, "Config file (YAML/JSON)") { |v| options[:config] = v }
  opts.on("--no-puma", "Use default Rack handler instead of Puma") { options[:use_puma] = false }
  opts.on("-h", "--help", "Show help") { puts opts; exit }
end.parse!(ARGV)

app = Hooks.build(config: options[:config])

if options[:use_puma]
  require "rack/handler/puma"
  Rack::Handler::Puma.run(app, Host: options[:bind], Port: options[:port], environment: options[:env])
else
  Rack::Handler.default.run(app, Host: options[:bind], Port: options[:port])
end
```

### Notes

* Puma is included as a runtime dependency and is the default server for all environments.
* The CLI is suitable for both development and production use.
* All configuration options can be set via CLI flags, ENV variables, or config files.
* The CLI prints a startup banner with the version, port, and loaded endpoints.

---

## 📦 13. Hello-World Default

When no configuration is provided, the framework serves a demo endpoint for verification:

**Endpoint:** `GET <root_path>/hello` (default: `/webhooks/hello`)

**Response:**

```json
{
  "message": "Hooks is working!",
  "version": "1.0.0",
  "timestamp": "2025-06-09T10:30:00Z"
}
```

This allows immediate verification that the framework is properly installed and running.

---

## 🚀 14. Production Deployment

### Docker Support

```dockerfile
FROM ruby:3.2-alpine
WORKDIR /app
COPY Gemfile* ./
RUN bundle install --deployment --without development test
COPY . .
EXPOSE 3000
CMD ["bundle", "exec", "puma", "-C", "config/puma.rb"]
```

### Health Check Integration

The health endpoint provides comprehensive status information for load balancers and monitoring:

```json
{
  "status": "healthy",
  "timestamp": "2025-06-09T10:30:00Z",
  "version": "1.0.0",
  "config_checksum": "abc123def456",
  "endpoints_loaded": 5,
  "plugins_loaded": 3,
  "uptime_seconds": 3600
}
```

### Performance Considerations

* **Thread Safety**: All core components are thread-safe for multi-threaded servers
* **Graceful Degradation**: Framework continues operating even if individual handlers fail

### Security Best Practices

* Use strong secrets for signature validation
* Keep handler code minimal and well-tested

---

## 📚 15. API Reference

### Core Classes

#### `Hooks::Handlers::Base`

Base class for all webhook handlers.

```ruby
class MyHandler < Hooks::Handlers::Base
  # @param payload [Hash, String] Parsed request body or raw string
  # @param headers [Hash<String, String>] HTTP headers
  # @param config [Hash] Merged endpoint configuration
  # @return [Hash, String, nil] Response body (auto-converted to JSON)
  def call(payload:, headers:, config:)
    # Handler implementation
    { status: "processed", id: generate_id }
  end
end
```

#### `Hooks::Plugins::Lifecycle`

Base class for global plugins with lifecycle hooks.

```ruby
class MyPlugin < Hooks::Plugins::Lifecycle
  # Called before handler execution
  # @param env [Hash] Rack environment
  def on_request(env)
    # Pre-processing logic
  end
  
  # Called after successful handler execution
  # @param env [Hash] Rack environment
  # @param response [Hash] Handler response
  def on_response(env, response)
    # Post-processing logic
  end
  
  # Called when any error occurs
  # @param exception [Exception] The raised exception
  # @param env [Hash] Rack environment
  def on_error(exception, env)
    # Error handling logic
  end
end
```

#### `Hooks::Plugins::SignatureValidator::Base`

Abstract base for custom signature validators.

```ruby
class CustomValidator < Hooks::Plugins::SignatureValidator::Base
  # @param payload [String] Raw request body
  # @param headers [Hash<String, String>] HTTP headers
  # @param secret [String] Secret key for validation
  # @param config [Hash] Endpoint configuration
  # @return [Boolean] true if signature is valid
  def self.valid?(payload:, headers:, secret:, config:)
    # Custom validation logic
    computed_signature = generate_signature(payload, secret)
    provided_signature = headers[config[:header]]
    secure_compare(computed_signature, provided_signature)
  end
end
```

---

## 🔒 HMAC Signature Validation Example

A typical HMAC validation in a handler or middleware might look like:

> This example shows how to implement HMAC signature validation in a handler or middleware for a sinatra-based app which is kinda close to Grape but not quite. It should be used as a reference as this is from GitHub's official docs on how to validate their webhooks.

```ruby
def verify_signature(payload_body)
  signature = 'sha256=' + OpenSSL::HMAC.hexdigest(OpenSSL::Digest.new('sha256'), ENV['SECRET_TOKEN'], payload_body)
  return halt 500, "Signatures didn't match!" unless Rack::Utils.secure_compare(signature, request.env['HTTP_X_HUB_SIGNATURE_256'])
end
```

This ensures the payload is authentic and untampered, using a shared secret and the SHA256 algorithm.

### Configuration Schema

Complete schema for endpoint configurations:

```yaml
# Required fields
path: string                    # Endpoint path (mounted under root_path)
handler: string                 # Handler class name

# Optional signature validation
auth:
  type: string                  # 'default' or custom validator class name
  secret_env_key: string        # ENV key containing secret
  header: string                # Header containing signature (default: X-Hub-Signature)
  algorithm: string             # Hash algorithm (default: sha256)

# Optional user-defined data
opts: hash                      # Arbitrary configuration data
```
