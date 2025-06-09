# `hooks` — A Pluggable Ruby Webhook Server Framework

## 📜 1. Project Overview

`hooks` is a **pure-Ruby**, **Grape-based**, **Rack-compatible** webhook server gem that:

* Dynamically mounts endpoints from per-team configs under a configurable `root_path`
* Loads **team handlers** and **global plugins** at boot, with priority ordering for hooks
* Validates configs via **Dry::Schema**, failing fast on invalid YAML/JSON/Hash
* Supports **signature validation** (default HMAC) and **custom validator** classes
* Enforces **allowed\_env\_vars** per endpoint—handlers can only read declared ENV keys
* Offers built-in **authentication modules**: IP whitelisting, API key, OAuth flows
* Applies **CORS policy** globally and allows **per-endpoint overrides**
* Enforces **request limits** (body size) and **timeouts**, configurable at runtime
* Emits **metrics events** (`:request_start`, `:request_end`, `:error`) for downstream integration
* Ships with operational endpoints:

  * **GET** `<health_path>`: liveness/readiness payload
  * **GET** `<metrics_path>`: JSON array of recent events
  * **GET** `<version_path>`: current gem version

* Supplies a **scaffold CLI** and **optional test helpers**
* Boots a demo `<root_path>/hello` route when no config is supplied, to verify setup

> **Server Agnostic:** `hooks` exports a Rack-compatible app. Mount under any Rack server (Puma, Unicorn, Thin, etc.).

---

## 🎯 2. Core Goals

1. **Config-Driven Endpoints**

   * Single file per endpoint: YAML, JSON, or Ruby Hash
   * Merged into `AppConfig` at boot, validated
   * Each endpoint `path` is prefixed by global `root_path` (default `/webhooks`)

2. **Plugin Architecture**

   * **Team Handlers**: `class MyHandler < Hooks::Handlers::Base`
   * **Global Plugins**: `class MyPlugin < Hooks::Plugins::Lifecycle`
   * **Signature Validators**: implement `.valid?(payload:, headers:, secret:, config:)`
   * **Hook Priority**: specify ordering in global settings

3. **Security & Isolation**

   * `allowed_env_vars` restricts ENV access per handler
   * **Sandbox** prevents `require`/`load` outside `handler_dir` and `plugin_dir`
   * Auth modules guard endpoints before handler invocation
   * Default JSON error responses, with detailed hooks

4. **Operational Endpoints**

   * **Health**: liveness/readiness, config checksums
   * **Metrics**: JSON events log (last N entries)
   * **Version**: gem version report

5. **Developer & Operator Experience**

   * Single entrypoint: `app = Hooks.build(...)`
   * Multiple configuration methods: path(s), ENV, Ruby Hash
   * Graceful shutdown on SIGINT/SIGTERM
   * Structured JSON logging with `request_id`, `path`, `handler`, timestamp
   * Scaffold generators for handlers and plugins
   * Optional `hooks-test` gem for RSpec support

---

## ⚙️ 3. Installation & Invocation

### Gemfile

```ruby
gem "hooks"
```

### Programmatic Invocation

```ruby
require "hooks"

# Returns a Rack-compatible app
app = Hooks.build(
  config:           "/path/to/endpoints/",      # Directory or Array/Hash
  settings:         "/path/to/settings.yaml",   # YAML, JSON, or Hash
  log:               MyCustomLogger.new,          # Optional logger (must respond to #info, #error, etc.)
  request_limit:     1_048_576,                   # Default max body size (bytes)
  request_timeout:   15,                         # Default timeout (seconds)
  cors: {                                   
    allow_origin:   "*",                      # Default CORS (merged with overrides)
    allow_methods:  ["GET","POST","OPTIONS"],
    allow_headers:  ["Content-Type","Authorization"]
  },
  root_path:        "/webhooks"               # Default mount prefix
)
```

Mount in `config.ru`:

```ruby
run app
```

### ENV-Based Bootstrap

```bash
export HOOKS_CONFIG_DIR=./config/endpoints
export HOOKS_SETTINGS=./config/settings.yaml
export HOOKS_LOGGER_CLASS=MyCustomLogger
export HOOKS_REQUEST_LIMIT=1048576
export HOOKS_REQUEST_TIMEOUT=15
export HOOKS_CORS='{"allow_origin":"*"}'
export HOOKS_ROOT_PATH="/webhooks"
ruby app.rb
```

> **Hello-World Mode**
> If invoked without `config` or `settings`, serves `GET <root_path>/hello`:
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
│   └── endpoint_builder.rb   # Wraps each route: CORS, auth, signature, hooks, handler
│
├── core/
│   ├── builder.rb            # Hooks.build: config loading, validation, signal handling - builds a rack compatible app
│   ├── config_loader.rb      # Loads + merges per-endpoint configs
│   ├── settings_loader.rb    # Loads global settings
│   ├── config_validator.rb   # Dry::Schema-based validation
│   ├── logger_factory.rb     # Structured JSON logger + context enrichment
│   ├── metrics_emitter.rb    # Event emitter for request metrics
│   ├── sandbox.rb            # Enforce require/load restrictions
│   └── signal_handler.rb     # Trap SIGINT/SIGTERM for graceful shutdown
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
├── auth/
│   ├── ip_whitelist.rb       # Checks `env['REMOTE_ADDR']`
│   ├── api_key.rb            # Validates header or param
│   └── oauth.rb              # Simple OAuth token validation
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
verify_signature:
  type: default               # 'default' uses HMACSHA256, or a custom class name
  secret_env_key: TEAM1_SECRET
  header: X-Hub-Signature
  algorithm: sha256

# Authentication (any mix)
auth:
  ip_whitelist:
    - 192.0.2.0/28
  api_keys:
    - KEY1
    - KEY2
  oauth:
    client_id_env: TEAM1_OAUTH_ID

allowed_env_vars:
  - TEAM1_SECRET
  - DATADOG_API_KEY

opts:                         # Freeform user-defined options
  env: staging
  teams: ["infra","billing"]

cors:                         # Overrides global CORS
  allow_origin: "https://github.com"
  allow_methods: ["POST"]
  allow_headers: ["Content-Type","X-Github-Event"]
```

### 5.2 Global Settings Config

```yaml
# config/settings.yaml
plugin_dir:      ./plugins          # global plugin directory
handler_dir:     ./handlers         # handler class directory
log_level:       info               # debug | info | warn | error
request_limit:   1048576            # max request body size (bytes)
request_timeout: 15                 # seconds to allow per request
cors:                                 # default CORS policy
  allow_origin:  "*"
  allow_methods: ["GET","POST","OPTIONS"]
  allow_headers: ["Content-Type","Authorization"]
root_path:       /webhooks          # base path for all endpoint routes - can be completely changed in endpoint configs, ex: /foo
health_path:     /health            # operational health endpoint
metrics_path:    /metrics           # operational metrics endpoint
version_path:    /version           # gem version endpoint
environment:     production         # development | production
```

---

## 🔍 6. Core Components & Flow

1. **Builder (`core/builder.rb`)**

   * Load settings (env or file) via `settings_loader`
   * Load endpoint configs via `config_loader`
   * Validate via `config_validator` (Dry::Schema); halt if invalid at boot
   * Initialize structured JSON logger via `logger_factory`
   * Emit startup `:request_start` for `/health`, `/metrics`, `/version`
   * Trap SIGINT/SIGTERM for graceful shutdown
   * Build and return Rack app from `app/api.rb`

2. **API Definition (`app/api.rb`)**

   * Uses Grape::API
   * Mounts:

     * `<root_path>/hello` (demo)
     * `<health_path>`, `<metrics_path>`, `<version_path>`
     * Each team endpoint under `<root_path>/<path>`

3. **Router & Endpoint Builder**

   * For each endpoint config:

     * Compose `effective_cors` = deep\_merge(global.cors, endpoint.cors)
     * Define Grape route with:

       * **Before**: enforce `request_limit`, `request_timeout`, CORS headers
       * **Auth**: apply IP whitelist, API key, OAuth
       * **Signature**: call custom or default validator
       * **Hooks**: run `on_request` plugins in priority order
     * **Handler**: invoke `MyHandler.new.call(payload:, headers:, config:)`
     * **After**: run `on_response` plugins
     * **Rescue**: on exception, emit metrics `:error`, run `on_error`, rethrow or format JSON error

4. **Metrics Emitter**

   * Listen to lifecycle events, build in-memory ring buffer of last N events
   * `/metrics` returns the JSON array of these events (configurable size)

5. **Graceful Shutdown**

   * On SIGINT/SIGTERM: allow in-flight requests to finish, exit

---

## 🔒 7. Security & Isolation

* **Allowed ENV Vars**: endpoints cannot access undisclosed ENV keys
* **Sandbox**: plugin & handler `require` limited to configured dirs
* **Authentication**: built-in modules guard routes
* **Request Validation**: size, timeout, signature, CORS enforced systematically
* **Error Handling**: exceptions bubble to Grape catchall, with JSON schema

---

## 🚨 8. Error Handling & Logging

* **Default JSON Error**:

  ```json
  { "error": "Error message", "code": 500 }
  ```

* **Dev Mode**: include full stack trace
* **Prod Mode**: hide backtrace, log internally
* **Structured Logs**: each entry includes:

  * `timestamp` (ISO8601)
  * `level`, `message`
  * `request_id`, `path`, `handler`, `status`, `duration_ms`
* **Lifecycle Hooks**: global plugins get `on_error(exception, env)`

---

## 📈 9. Metrics & Instrumentation

* Hooks for:

  * `:request_start` (path, method, request\_id)
  * `:request_end` (status, duration)
  * `:error` (exception details)
* Users subscribe via global plugins to forward to StatsD, Prometheus, etc.

---

## 🛠️ 11. CLI & Scaffolding

`bin/hooks`:

```bash
# Create a new handler skeleton
hooks scaffold handler my_endpoint

# Create a new global plugin skeleton
hooks scaffold plugin my_plugin
```

Generates:

* `handlers/my_endpoint_handler.rb`
* `config/endpoints/my_endpoint.yaml`
* `plugins/my_plugin.rb`

---

## 🧪 12. Testing Helpers (Optional)

Add to `Gemfile, group :test`:

```ruby
gem "hooks-test"
```

Provides modules and RSpec matchers to:

* Stub ENV safely
* Simulate HTTP requests against Rack app
* Assert metrics and hook invocations

---

## 📦 13. Hello-World Default

If no config provided, `/webhooks/hello` responds:

```json
{ "message": "Hooks is working!" }
```
