# Auth Plugins

This document provides an example of how to implement a custom authentication plugin for a hypothetical system. The plugin checks for a specific authorization header and validates it against a secret stored in an environment variable.

In your global configuration file (e.g. `hooks.yml`) you would likely set `auth_plugin_dir` to something like `./plugins/auth`.

Here is an example snippet of how you might configure the global settings in `hooks.yml`:

```yaml
# hooks.yml
auth_plugin_dir: ./plugins/auth # Directory where custom auth plugins are stored
```

Then place your custom auth plugin in the `./plugins/auth` directory, for example `./plugins/auth/some_cool_auth_plugin.rb`.

```ruby
# frozen_string_literal: true
# Example custom auth plugin implementation
module Hooks
  module Plugins
    module Auth
      class SomeCoolAuthPlugin < Base
        def self.valid?(payload:, headers:, config:)
          # Get the secret from environment variable
          secret = fetch_secret(config) # by default, this will fetch the value of the environment variable specified in the config (e.g. SUPER_COOL_SECRET as defined by `secret_env_key`)

          # Get the authorization header (case-insensitive)
          auth_header = nil
          headers.each do |key, value|
            if key.downcase == "authorization"
              auth_header = value
              break
            end
          end

          # Check if the header matches our expected format
          return false unless auth_header

          # Extract the token from "Bearer <token>" format
          return false unless auth_header.start_with?("Bearer ")

          token = auth_header[7..-1] # Remove "Bearer " prefix

          # Simple token comparison (in practice, this might be more complex)
          token == secret
        end
      end
    end
  end
end
```

Then you could create a new endpoint configuration that references this plugin:

```yaml
path: /example
handler: CoolNewHandler

auth:
  type: some_cool_auth_plugin # using the newly created auth plugin as seen above
  secret_env_key: SUPER_COOL_SECRET # the name of the environment variable containing the shared secret - used by `fetch_secret(config)` in the plugin
  header: Authorization
```
