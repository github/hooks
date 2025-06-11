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

## Usage 💻

### Basic

```ruby
# file: config.ru
require "hooks-ruby"

app = Hooks.build(config: "hooks.yaml")
run app
```

Run the hooks server:

```bash
bundle exec puma --tag hooks
```

### Advanced

TODO
