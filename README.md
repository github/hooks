# hooks

[![build](https://github.com/github/hooks/actions/workflows/build.yml/badge.svg)](https://github.com/github/hooks/actions/workflows/build.yml)
[![test](https://github.com/github/hooks/actions/workflows/test.yml/badge.svg)](https://github.com/github/hooks/actions/workflows/test.yml)
[![lint](https://github.com/github/hooks/actions/workflows/lint.yml/badge.svg)](https://github.com/github/hooks/actions/workflows/lint.yml)
[![integration](https://github.com/github/hooks/actions/workflows/integration.yml/badge.svg)](https://github.com/github/hooks/actions/workflows/integration.yml)

A Pluggable Webhook Server Framework written in Ruby.

![hooks](docs/assets/hooks.png)

## About ⭐

Hooks is a RESTful webhook server framework written in Ruby. It is designed to be simple, flexible, and extensible, allowing you to easily create and manage webhook endpoints for your applications. Hooks is designed to consolidate and process incoming webhook requests in a single place, making it easier to handle webhooks from multiple sources.

**Why Hooks?**: If you have to handle webhooks from multiple sources, you might end up with a lot of code that is similar but not quite the same. Hooks allows you to define a set of common behaviors and then extend them with plugins, so you can handle webhooks in a consistent way across your application.

## Features 🚀

- **Pluggable Architecture**: Easily extend the functionality of your webhook server with plugins for authentication, handlers, and more.
- **Flexible Configuration**: Customize your webhook server via a simple configuration file, or programmatically with pure Ruby.
- **Built-in Auth Plugins**: Support for common authentication methods like HMAC, shared secrets, and more.

## How It Works 🔧

Hooks is designed to be very easy to setup and use. It provides a simple DSL for defining webhook endpoints and then you can use plugins to handle the incoming requests and optionally authenticate them.

Here is a very high-level overview of how Hooks works:

1. You define a global configuration file (e.g. `hooks.yml`) where you can specify where your webhook endpoint configs are located, and the directory where your plugins are located. Here is an example of a minimal configuration file:

    ```yaml
    # file: hooks.yml
    handler_plugin_dir: ./plugins/handlers
    auth_plugin_dir: ./plugins/auth
    endpoints_dir: ./config/endpoints

    log_level: debug

    root_path: /webhooks
    health_path: /health
    version_path: /version

    environment: development
    ```

2. Then in your `config/endpoints` directory, you can define all your webhook endpoints in separate files. Here is an example of a simple endpoint configuration file:

    ```yaml
    # file: config/endpoints/hello.yml
    path: /hello
    handler: MyCustomHandler # This is a custom handler plugin you would define in the plugins/handlers directory
    ```

3. Now create a corresponding handler plugin in the `plugins/handlers` directory. Here is an example of a simple handler plugin:

    ```ruby
    # file: plugins/handlers/my_custom_handler.rb
    class MyCustomHandler < Hooks::Plugins::Handlers::Base
      def call(payload:, headers:, config:)
        # Process the incoming webhook - optionally use the payload and headers
        # to perform some action or validation
        # For this example, we will just return a success message
        {
          status: "success",
          handler: "MyCustomHandler",
          payload_received: payload,
          timestamp: Time.now.iso8601
        }
      end
    end
    ```

That is pretty much it! Below you will find more detailed instructions on how to install and use Hooks, as well as how to create your own plugins. This high-level overview should give you a good idea of how Hooks works and how you can use it to handle webhooks in your applications. You may also be interested in using your own custom authentication plugins to secure your webhook endpoints, which is covered in the [Authentication](#authentication) section below.

## Installation 💎

You can download this Gem from [GitHub Packages](https://github.com/github/hooks/pkgs/rubygems/hooks-ruby) or [RubyGems](https://rubygems.org/gems/hooks-ruby)

Via a Gemfile:

```ruby
source "https://rubygems.org"

gem "hooks-ruby", "~> X.X.X" # Replace X.X.X with the latest version
```

Once added to your Gemfile, run:

```bash
bundle install
```

## Usage 💻

### Basic

Here is a simple example of how to set up a Hooks server.

First, create a `config.ru` file:

```ruby
# file: config.ru
require "hooks-ruby"

# See the config documentation below for the full list of available options
# For this example, we will just set use_catchall_route to true
config = {
  use_catchall_route: true # will use the DefaultHandler for /webhooks/* - just an example/demo
}

# Builds the Hooks application with the provided configuration
app = Hooks.build(config: config)

# Run the Hooks application when the server starts
run app
```

Run the hooks server via puma which is the recommended server for Hooks:

```bash
bundle exec puma --tag hooks
```

Send a webhook request to the server in a separate terminal:

```bash
curl --request POST \
  --url http://0.0.0.0:9292/webhooks/hello \
  --header 'content-type: application/json' \
  --data '{}'

# => { "message": "webhook processed successfully", "handler": "DefaultHandler", "timestamp": "2025-06-10T23:15:07-07:00" }
```

Congratulations! You have successfully set up a basic Hooks server which will listen to anything under `/webhooks/*` and respond with a success message.

Keep reading to learn how to customize your Hooks server with different plugins for handlers, authentication, and more.

### Advanced

TODO

### Authentication

TODO

See the [Auth Plugins](docs/auth_plugins.md) documentation for more information on how to create your own custom authentication plugins.
