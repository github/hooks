# Handler Plugins

This document provides in-depth information about handler plugins and how you can create your own to extend the functionality of the Hooks framework for your own deployment.

## Writing a Handler Plugin

Handler plugins are Ruby classes that extend the `Hooks::Plugins::Handlers::Base` class. They are used to process webhook payloads and can do anything you want. They follow a very simple interface that allows you to define a `call` method that takes three parameters: `payload`, `headers`, and `config`. The `call` method should return a hash with the response data. The hash that this method returns will be sent back to the webhook sender as a JSON response.

- `payload`: The webhook payload, which can be a Hash or a String. This is the data that the webhook sender sends to your endpoint.
- `headers`: A Hash of HTTP headers that were sent with the webhook request.
- `config`: A Hash containing the endpoint configuration. This can include any additional settings or parameters that you want to use in your handler. Most of the time, this won't be used but sometimes endpoint configs add `opts` that can be useful for the handler.

```ruby
# example file path: plugins/handlers/example.rb
class Example < Hooks::Plugins::Handlers::Base
  # Process a webhook payload
  #
  # @param payload [Hash, String] webhook payload (pure JSON with string keys)
  # @param headers [Hash] HTTP headers (string keys, optionally normalized)
  # @param config [Hash] Endpoint configuration
  # @return [Hash] Response data
  def call(payload:, headers:, config:)
    return {
      status: "success"
    }
  end
end
```

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

### `config` Parameter

The `config` parameter is a Hash (symbolized) that contains the endpoint configuration. This can include any additional settings or parameters that you want to use in your handler. Most of the time, this won't be used, but sometimes endpoint configs add `opts` that can be useful for the handler.

## Built-in Features

This section goes into details on the built-in features that exist in all handler plugins that extend the `Hooks::Plugins::Handlers::Base` class.

### `#log`

The `log.debug`, `log.info`, `log.warn`, and `log.error` methods are available in all handler plugins. They are used to log messages at different levels of severity.

### `#Retryable.with_context(:default)`

This method uses a default `Retryable` context to handle retries. It is used to wrap the execution of a block of code that may need to be retried in case of failure.

Here is how it can be used in a handler plugin:

```ruby
class Example < Hooks::Plugins::Handlers::Base
  # Example webhook handler
  #
  # @param payload [Hash, String] Webhook payload
  # @param headers [Hash<String, String>] HTTP headers
  # @param config [Hash] Endpoint configuration
  # @return [Hash] Response data
  def call(payload:, headers:, config:)
    result = Retryable.with_context(:default) do
      some_operation_that_might_fail()
    end

    log.debug("operation result: #{result}")

    return {
      status: "success"
    }
  end
end
```

> If `Retryable.with_context(:default)` fails after all retries, it will re-raise the last exception encountered.

See the source code at `lib/hooks/utils/retry.rb` for more details on how `Retryable.with_context(:default)` works.
