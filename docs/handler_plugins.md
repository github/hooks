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
  # @param payload [Hash, String] webhook payload
  # @param headers [Hash<String, String>] HTTP headers
  # @param config [Hash] Endpoint configuration
  # @return [Hash] Response data
  def call(payload:, headers:, config:)
    return {
      status: "success"
    }
  end
end
```

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
