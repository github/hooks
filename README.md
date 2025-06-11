# hooks

[![build](https://github.com/github/hooks/actions/workflows/build.yml/badge.svg)](https://github.com/github/hooks/actions/workflows/build.yml)
[![test](https://github.com/github/hooks/actions/workflows/test.yml/badge.svg)](https://github.com/github/hooks/actions/workflows/test.yml)
[![lint](https://github.com/github/hooks/actions/workflows/lint.yml/badge.svg)](https://github.com/github/hooks/actions/workflows/lint.yml)
[![integration](https://github.com/github/hooks/actions/workflows/integration.yml/badge.svg)](https://github.com/github/hooks/actions/workflows/integration.yml)

A Pluggable Webhook Server Framework written in Ruby

![hooks](docs/assets/hooks.png)

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
