# Configuration

This document describes how you can configure your **Hooks** server to run.

There are two type of configurations:

- **Global Options** - These options are set in the `hooks.yaml` file and apply to the entire server.
- **Endpoint Options** - These options are set in each endpoint's configuration file and apply only to that specific endpoint.

## Global Options

### `endpoints_dir`

The directory containing endpoint configuration files. Each file in this directory defines a specific webhook endpoint and its configuration.

**Example:** `./config/endpoints`

### `handler_plugin_dir`

The directory where the handler plugins are located. Handlers are responsible for processing incoming webhook requests. A handler plugin directory should contain one or more handlers that are Ruby files. For more information on handler plugins, see the [Handler Plugins documentation](./handler_plugins.md).

**Example:** `./plugins/handlers`

### `auth_plugin_dir`

The directory where the authentication plugins are located. Authentication plugins are responsible for validating incoming webhook requests before they are processed by handlers. For more information on authentication plugins, see the [Auth Plugins documentation](./auth_plugins.md).

**Example:** `./plugins/auth`

### `lifecycle_plugin_dir`

The directory where the lifecycle plugins are located. Lifecycle plugins allow you to hook into various stages of the webhook processing lifecycle. For more information on lifecycle plugins, see the [Lifecycle Plugins documentation](./lifecycle_plugins.md).

**Example:** `./plugins/lifecycle`

### `instruments_plugin_dir`

The directory where the instrumentation plugins are located. Instrumentation plugins are responsible for collecting metrics and monitoring data from the webhook server. For more information on instrumentation plugins, see the [Instrument Plugins documentation](./instrument_plugins.md).

**Example:** `./plugins/instruments`

### `log_level`

Sets the logging level for the server. Valid values are `debug`, `info`, `warn`, `error`, and `fatal`.

**Default:** `info`  
**Example:** `debug`

### `request_limit`

The maximum size (in bytes) allowed for incoming request bodies. This helps prevent memory exhaustion from extremely large payloads.

**Default:** `1048576` (1MB)  
**Example:** `1048576`

### `request_timeout`

The maximum time (in seconds) to wait for an incoming request to complete before timing out.

**Default:** `30`  
**Example:** `15`

### `root_path`

The base path for all webhook endpoints. All endpoint routes will be prefixed with this path.

**Default:** `/webhooks`  
**Example:** `/webhooks`

### `health_path`

The path for the health check endpoint. This endpoint returns the server's health status.

**Default:** `/health`  
**Example:** `/health`

### `version_path`

The path for the version endpoint. This endpoint returns the server's version information.

**Default:** `/version`  
**Example:** `/version`

### `environment`

Specifies the runtime environment for the server. This can affect logging, error handling, and other behaviors. Warning - running in development mode will return full stack traces in error responses.

**Default:** `production`  
**Example:** `development`

### `use_catchall_route`

When set to `true`, enables a catch-all route that will handle requests to unknown endpoints. When `false`, requests to undefined endpoints will return a 404 error.

**Default:** `false`  
**Example:** `false`

## Endpoint Options

### `path`

The path for the webhook endpoint. This is the URL that clients will use to send webhook requests. It should be unique across all endpoints. Simply stating the path will create a route like `/webhooks/{path}`.

**Example:** `/github` will create the route `/webhooks/github` if `root_path` is set to `/webhooks`.

### `handler`

The name of the Ruby class that will handle the incoming webhook requests for this endpoint. The handler class should be defined in the `handler_plugin_dir`. For example, if you have a handler class named `GithubHandler`, you would specify it as follows:

```yaml
handler: GithubHandler
```

> For readability, you should use CamelCase for handler names, as they are Ruby classes. You should then name the file in the `handler_plugin_dir` as `github_handler.rb`.

### `method`

The HTTP method that the endpoint will respond to. This allows you to configure endpoints for different HTTP verbs based on your webhook provider's requirements.

**Default:** `post`  
**Valid values:** `get`, `post`, `put`, `patch`, `delete`, `head`, `options`

**Example:**

```yaml
method: post  # Most webhooks use POST
# or
method: put   # Some REST APIs might use PUT for updates
```

In some cases, webhook providers (such as Okta) may require a one time verification request via a GET request. In such cases, you can set the method to `get` for that specific endpoint and then write a handler that processes the verification request.

### `auth`

Authentication configuration for the endpoint. This section defines how incoming requests will be authenticated before being processed by the handler.

Each auth plugin can have its own configuration options. The `type` field is required though, and it specifies which authentication plugin to use. The available types are defined in the `auth_plugin_dir`.

**Example:**

```yaml
auth:
  type: hmac
  secret_env_key: GITHUB_WEBHOOK_SECRET
  header: X-Hub-Signature-256
  algorithm: sha256
  format: "algorithm=signature"  # produces "sha256=abc123..."
```

See the [Auth Plugins documentation](./auth_plugins.md) for more details on how to implement custom authentication plugins. You will also find configurations for built-in authentication plugins in that document as well.

### `opts`

Additional options for the endpoint. This section can include any custom options that the handler may require. The options are specific to the handler and can vary based on its implementation. You can put anything your heart desires here.
