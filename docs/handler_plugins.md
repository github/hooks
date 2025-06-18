# Handler Plugins

This document provides in-depth information about handler plugins and how you can create your own to extend the functionality of the Hooks framework for your own deployment.

## Writing a Handler Plugin

Handler plugins are Ruby classes that extend the `Hooks::Plugins::Handlers::Base` class. They are used to process webhook payloads and can do anything you want. They follow a very simple interface that allows you to define a `call` method that takes four parameters: `payload`, `headers`, `env`, and `config`.

**Important:** The `call` method should return a hash by default. Since the server now defaults to JSON format, any hash returned by the handler will be automatically converted to JSON with the correct `Content-Type: application/json` headers set by Grape. This ensures consistent API responses and proper JSON serialization.

- `payload`: The webhook payload, which can be a Hash or a String. This is the data that the webhook sender sends to your endpoint.
- `headers`: A Hash of HTTP headers that were sent with the webhook request.
- `env`: A modified Rack environment that contains a lot of context about the request. This includes information about the request method, path, query parameters, and more. See [`rack_env_builder.rb`](../lib/hooks/app/rack_env_builder.rb) for the complete list of available keys.
- `config`: A Hash containing the endpoint configuration. This can include any additional settings or parameters that you want to use in your handler. Most of the time, this won't be used but sometimes endpoint configs add `opts` that can be useful for the handler.

The method should return a **hash** that will be automatically serialized to JSON format with appropriate headers. The server defaults to JSON format for both input and output processing.

```ruby
# example file path: plugins/handlers/example.rb
class Example < Hooks::Plugins::Handlers::Base
  # Process a webhook payload
  #
  # @param payload [Hash, String] webhook payload (pure JSON with string keys)
  # @param headers [Hash] HTTP headers (string keys, optionally normalized - default is normalized)
  # @param env [Hash] A modified Rack environment that contains a lot of context about the request
  # @param config [Hash] Endpoint configuration
  # @return [Hash] Response data (automatically converted to JSON)
  def call(payload:, headers:, env:, config:)
    # Return a hash - it will be automatically converted to JSON with proper headers
    return {
      status: "success",
      message: "webhook processed successfully",
      timestamp: Time.now.iso8601
    }
  end
end
```

After you write your own handler, it can be referenced in endpoint configuration files like so:

```yaml
# example file path: config/endpoints/example.yml
path: /example_webhook
handler: example # this is the name of the handler plugin class
```

It should be noted that the `handler:` key in the endpoint configuration file should match the name of the handler plugin class, but in lowercase and snake case. For example, if your handler plugin class is named `ExampleHandler`, the `handler:` key in the endpoint configuration file should be `example_handler`. Here are some more examples:

- `ExampleHandler` -> `example_handler`
- `MyCustomHandler` -> `my_custom_handler`
- `Cool2Handler` -> `cool_2_handler`

## Default JSON Format

By default, the Hooks server uses JSON format for both input and output processing. This means:

- **Input**: Webhook payloads are parsed as JSON and passed to handlers as Ruby hashes
- **Output**: Handler return values (hashes) are automatically converted to JSON responses with `Content-Type: application/json` headers
- **Error Responses**: Authentication failures and handler errors return structured JSON responses

**Best Practice**: Always return a hash from your handler's `call` method. The hash will be automatically serialized to JSON and sent to the webhook sender with proper headers. This ensures consistent API responses and proper JSON formatting.

Example response format:

```json
{
  "status": "success",
  "message": "webhook processed successfully", 
  "data": {
    "processed_at": "2023-10-01T12:34:56Z",
    "items_processed": 5
  }
}
```

> **Note**: The JSON format behavior can be configured using the `default_format` option in your global configuration. See the [Configuration documentation](./configuration.md) for more details.

### `payload` Parameter

The `payload` parameter can be a Hash or a String. If the payload is a String, it will be parsed as JSON. If it is a Hash, it will be passed directly to the handler. The payload can contain any data that the webhook sender wants to send.

The payload is parsed as JSON (if it can be) and returned as a pure Ruby hash with string keys, maintaining the original JSON structure. This ensures that the payload is always a valid JSON representation that can be easily serialized and processed.

**TL;DR**: The payload is almost always a Hash with string keys, regardless of whether the original payload was a Hash or a JSON String.

For example, if the client sends the following JSON payload:

```json
{
  "hello": "world",
  "foo": ["bar", "baz"],
  "truthy": true,
  "coffee": {"is": "good"}
}
```

It will be parsed and passed to the handler as:

```ruby
{
  "hello" => "world",
  "foo" => ["bar", "baz"],
  "truthy" => true,
  "coffee" => {"is" => "good"}
}
```

### `headers` Parameter

The `headers` parameter is a Hash that contains the HTTP headers that were sent with the webhook request. It includes standard headers like `host`, `user-agent`, `accept`, and any custom headers that the webhook sender may have included.

By default, the headers are normalized (lowercased and trimmed) but kept as string keys to maintain their JSON representation. Header keys are always strings, and any normalization simply ensures consistent formatting (lowercasing and trimming whitespace). You can disable header normalization by setting the environment variable `HOOKS_NORMALIZE_HEADERS` to `false` or by setting the `normalize_headers` option to `false` in the global configuration file.

**TL;DR**: The headers are always a Hash with string keys, optionally normalized for consistency.

For example, if the client sends the following headers:

```text
Host: hooks.example.com
User-Agent: foo-client/1.0
Accept: application/json, text/plain, */*
Accept-Encoding: gzip, compress, deflate, br
Client-Name: foo
X-Forwarded-For: <IP_ADDRESS>
X-Forwarded-Host: hooks.example.com
X-Forwarded-Proto: https
Authorization: Bearer <TOKEN>
```

They will be normalized and passed to the handler as:

```ruby
{
  "host" => "hooks.example.com",
  "user-agent" => "foo-client/1.0",
  "accept" => "application/json, text/plain, */*",
  "accept-encoding" => "gzip, compress, deflate, br",
  "client-name" => "foo",
  "x-forwarded-for" => "<IP_ADDRESS>",
  "x-forwarded-host" => "hooks.example.com",
  "x-forwarded-proto" => "https",
  "authorization" => "Bearer <TOKEN>" # a careful reminder that headers *can* contain sensitive information!
}
```

It should be noted that the `headers` parameter is a Hash with **string keys** (not symbols). They are optionally normalized (lowercased and trimmed) to ensure consistency.

You can disable header normalization by either setting the environment variable `HOOKS_NORMALIZE_HEADERS` to `false` or by setting the `normalize_headers` option to `false` in the global configuration file.

### `env` Parameter

The `env` parameter is a Hash that contains a modified Rack environment. It provides a lot of context about the request, including information about the request method, path, query parameters, and more. This can be useful for debugging or for accessing additional request information. It is considered *everything plus the kitchen sink* that you might need to know about the request.

Here is a partial example of what the `env` parameter might look like:

```ruby
{
  "REQUEST_METHOD" => "POST",
  "PATH_INFO" => "/webhooks/example",
  "QUERY_STRING" => "foo=bar&baz=123",
  "HTTP_VERSION" => "HTTP/1.1",
  "REQUEST_URI" => "https://hooks.example.com/webhooks/example?foo=bar&baz=qux",
  "SERVER_NAME" => "hooks.example.com",
  "SERVER_PORT" => 443,
  "CONTENT_TYPE" => "application/json",
  "CONTENT_LENGTH" => 123,
  "REMOTE_ADDR" => "<IP_ADDRESS>",
  "hooks.request_id" => "<REQUEST_ID>",
  "hooks.handler" => "ExampleHandler"
  "hooks.endpoint_config" => {}
  "hooks.start_time" => "2023-10-01T12:34:56Z",
  # etc...
}
```

For the complete list of available keys in the `env` parameter, you can refer to the source code at [`lib/hooks/app/rack_env_builder.rb`](../lib/hooks/app/rack_env_builder.rb).

### `config` Parameter

The `config` parameter is a Hash (symbolized) that contains the endpoint configuration. This can include any additional settings or parameters that you want to use in your handler. Most of the time, this won't be used, but sometimes endpoint configs add `opts` that can be useful for the handler.

## Built-in Features

This section goes into details on the built-in features that exist in all handler plugins that extend the `Hooks::Plugins::Handlers::Base` class.

### `#log`

The `log.debug`, `log.info`, `log.warn`, and `log.error` methods are available in all handler plugins. They are used to log messages at different levels of severity.

### `#error!`

All handler plugins have access to the `error!` method, which is used to raise an error with a specific message and HTTP status code. This is useful for returning error responses to the webhook sender.

When using `error!` with the default JSON format, both hash and string responses are handled appropriately:

```ruby
class Example < Hooks::Plugins::Handlers::Base
  # Example webhook handler
  #
  # @param payload [Hash, String] Webhook payload
  # @param headers [Hash<String, String>] HTTP headers
  # @param env [Hash] A modified Rack environment that contains a lot of context about the request
  # @param config [Hash] Endpoint configuration
  # @return [Hash] Response data (automatically converted to JSON)
  def call(payload:, headers:, env:, config:)

    if payload.nil? || payload.empty?
      log.error("Payload is empty or nil")
      # String errors are JSON-encoded with default format
      error!("Payload cannot be empty or nil", 400)
    end

    return {
      status: "success"
    }
  end
end
```

**Recommended approach**: Use hash-based error responses for consistent JSON structure:

```ruby
class Example < Hooks::Plugins::Handlers::Base
  def call(payload:, headers:, env:, config:)

    if payload.nil? || payload.empty?
      log.error("Payload is empty or nil")
      # Hash errors are automatically converted to JSON
      error!({
        error: "payload_empty",
        message: "the payload cannot be empty or nil",
        success: false,
        custom_value: "some_custom_value",
        request_id: env["hooks.request_id"]
      }, 400)
    end

    return {
      status: "success"
    }
  end
end
```

This will return a properly formatted JSON error response:

```json
{
  "error": "payload_empty",
  "message": "the payload cannot be empty or nil",
  "success": false,
  "custom_value": "some_custom_value",
  "request_id": "uuid-here"
}
```

### `#Retryable.with_context(:default)`

This method uses a default `Retryable` context to handle retries. It is used to wrap the execution of a block of code that may need to be retried in case of failure.

Here is how it can be used in a handler plugin:

```ruby
class Example < Hooks::Plugins::Handlers::Base
  # Example webhook handler
  #
  # @param payload [Hash, String] Webhook payload
  # @param headers [Hash<String, String>] HTTP headers
  # @param env [Hash] A modified Rack environment that contains a lot of context about the request
  # @param config [Hash] Endpoint configuration
  # @return [Hash] Response data (automatically converted to JSON)
  def call(payload:, headers:, env:, config:)
    result = Retryable.with_context(:default) do
      some_operation_that_might_fail()
    end

    log.debug("operation result: #{result}")

    return {
      status: "success",
      operation_result: result,
      processed_at: Time.now.iso8601
    }
  end
end
```

> If `Retryable.with_context(:default)` fails after all retries, it will re-raise the last exception encountered.

See the source code at `lib/hooks/utils/retry.rb` for more details on how `Retryable.with_context(:default)` works.

### `#failbot` and `#stats`

The `failbot` and `stats` methods are available in all handler plugins. They are used to report errors and send statistics, respectively. These are custom methods and you can learn more about them in the [Instrumentation Plugins](instrument_plugins.md) documentation.
