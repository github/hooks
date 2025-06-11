# Handler Plugins

This document provides in-depth information about handler plugins and how you can create your own to extend the functionality of the Hooks framework for your own deployment.

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
