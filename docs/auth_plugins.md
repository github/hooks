# Auth Plugins

This document provides information on how to use authentication plugins for webhook validation, including built-in plugins and how to implement custom authentication plugins.

In your global configuration file (e.g. `hooks.yml`) you would likely set `auth_plugin_dir` to something like `./plugins/auth`.

Here is an example snippet of how you might configure the global settings in `hooks.yml`:

```yaml
# hooks.yml
auth_plugin_dir: ./plugins/auth # Directory where custom auth plugins are stored
```

## Built-in Auth Plugins

The system comes with several built-in authentication plugins that cover common webhook authentication patterns.

### HMAC Authentication

The HMAC plugin provides secure signature-based authentication using HMAC (Hash-based Message Authentication Code). This is the most secure authentication method and is used by major webhook providers like GitHub, GitLab, and Shopify.

It works well because it HMACs provide the ability to verify both the integrity and authenticity of the request, ensuring that the payload has not been tampered with and that it comes from a trusted source.

**Type:** `hmac`

#### HMAC Configuration Options

##### `secret_env_key` (required)

The name of the environment variable containing the shared secret used for HMAC signature generation.

**Example:** `GITHUB_WEBHOOK_SECRET`

##### `header`

The HTTP header containing the HMAC signature.

**Default:** `X-Signature`  
**Example:** `X-Hub-Signature-256`

##### `algorithm`

The hashing algorithm to use for HMAC signature generation.

**Default:** `sha256`  
**Valid values:** `sha1`, `sha256`, `sha384`, `sha512`  
**Example:** `sha256`

##### `format`

The format of the signature in the header. This determines how the signature is structured.

**Default:** `algorithm=signature`  

**Valid values:**

- `algorithm=signature` - Produces "sha256=abc123..." (GitHub, GitLab style)
- `signature_only` - Produces "abc123..." (Shopify style)  
- `version=signature` - Produces "v0=abc123..." (Slack style)

##### `version_prefix`

The version prefix used when `format` is set to `version=signature`.

**Default:** `v0`  
**Example:** `v1`

##### `timestamp_header` (optional)

The HTTP header containing the request timestamp for timestamp validation. When specified, requests must include a valid timestamp within the tolerance window.

**Example:** `X-Request-Timestamp`

##### `timestamp_tolerance`

The maximum age (in seconds) allowed for timestamped requests. Only used when `timestamp_header` is specified.

**Default:** `300` (5 minutes)  
**Example:** `600`

##### `payload_template` (optional)

A template for constructing the payload used in signature generation when timestamp validation is enabled. Use placeholders like `{version}`, `{timestamp}`, and `{body}`.

**Example:** `{version}:{timestamp}:{body}` (Slack-style), `{timestamp}.{body}` (Tailscale-style)

##### `header_format` (optional)

The format of the signature header content. Use "structured" for headers containing comma-separated key-value pairs.

**Default:** `simple`  
**Valid values:**

- `simple` - Standard single-value headers like "sha256=abc123..." or "abc123..."
- `structured` - Comma-separated key-value pairs like "t=1663781880,v1=abc123..."

##### `signature_key` (optional)

When `header_format` is "structured", this specifies the key name for the signature value in the header.

**Default:** `v1`  
**Example:** `signature`

##### `timestamp_key` (optional)

When `header_format` is "structured", this specifies the key name for the timestamp value in the header.

**Default:** `t`  
**Example:** `timestamp`

##### `structured_header_separator` (optional)

When `header_format` is "structured", this specifies the separator used between the unique keys in the structured header.

For example, if the header is `t=1663781880,v1=abc123`, the `structured_header_separator` would be `,`. It defaults to `,` but can be changed if needed.

**Example:** `.`
**Default:** `,`

##### `key_value_separator` (optional)

When `header_format` is "structured", this specifies the separator used between the key and value in the structured header.

For example, in the header `t=1663781880,v1=abc123`, the `key_value_separator` would be `=`. It defaults to `=` but can be changed if needed.

**Example:** `:`
**Default:** `=`

#### HMAC Examples

**Basic GitHub-style HMAC:**

```yaml
auth:
  type: hmac
  secret_env_key: GITHUB_WEBHOOK_SECRET
  header: X-Hub-Signature-256
  algorithm: sha256
  format: "algorithm=signature"  # produces "sha256=abc123..."
```

**Shopify-style HMAC (signature only):**

```yaml
auth:
  type: hmac
  secret_env_key: SHOPIFY_WEBHOOK_SECRET
  header: X-Shopify-Hmac-Sha256
  algorithm: sha256
  format: "signature_only"  # produces "abc123..."
```

**Slack-style HMAC with timestamp validation:**

This is the most secure authentication method as it includes timestamp validation directly in the HMAC signature, preventing replay attacks even if an attacker intercepts the request.

```yaml
auth:
  type: hmac
  secret_env_key: SLACK_WEBHOOK_SECRET
  header: X-Slack-Signature
  timestamp_header: X-Slack-Request-Timestamp
  timestamp_tolerance: 300  # 5 minutes
  algorithm: sha256
  format: "version=signature"  # produces "v0=abc123..."
  version_prefix: "v0"
  payload_template: "{version}:{timestamp}:{body}"
```

**Security Benefits:**

The timestamp validation provides several critical security advantages:

1. **Replay Attack Prevention**: Even if an attacker captures a valid request, they cannot replay it after the timestamp tolerance window expires
2. **HMAC Integrity**: The timestamp is included in the HMAC calculation itself (via `payload_template`), so tampering with either the timestamp or payload will invalidate the signature
3. **Time-bound Validity**: Requests are only valid within a specific time window, reducing the attack surface

**How it works:**

1. The client includes the current Unix timestamp in the `X-Slack-Request-Timestamp` header
2. The HMAC is calculated over a constructed payload using the template: `{version}:{timestamp}:{body}`
3. For example, if the version is "v0", timestamp is "1609459200", and body is `{"event":"push"}`, the signed payload becomes: `v0:1609459200:{"event":"push"}`
4. The resulting signature format is: `v0=computed_hmac_hash`

**Example curl request:**

```bash
#!/bin/bash

# Configuration
WEBHOOK_URL="https://your-hooks-server.com/webhooks/slack"
SECRET="your_slack_webhook_secret"
TIMESTAMP=$(date +%s)
PAYLOAD='{"event":"push","repository":"my-repo"}'

# Construct the signing payload
VERSION="v0"
SIGNING_PAYLOAD="${VERSION}:${TIMESTAMP}:${PAYLOAD}"

# Generate HMAC signature
SIGNATURE=$(echo -n "$SIGNING_PAYLOAD" | openssl dgst -sha256 -hmac "$SECRET" -hex | cut -d' ' -f2)
FORMATTED_SIGNATURE="${VERSION}=${SIGNATURE}"

# Send the request
curl -X POST "$WEBHOOK_URL" \
  -H "Content-Type: application/json" \
  -H "X-Slack-Signature: $FORMATTED_SIGNATURE" \
  -H "X-Slack-Request-Timestamp: $TIMESTAMP" \
  -d "$PAYLOAD"
```

**Important Security Notes:**

- The timestamp must be included in the HMAC calculation (not just validated separately) to prevent signature reuse with different timestamps
- Use a reasonable `timestamp_tolerance` (5-10 minutes) to account for clock skew while minimizing replay window
- Always use HTTPS to prevent man-in-the-middle attacks
- Store webhook secrets securely

**General HMAC with timestamp validation (no version):**

For services that require timestamp validation but don't use version prefixes, you can use a simpler template format with the standard `algorithm=signature` format.

```yaml
auth:
  type: hmac
  secret_env_key: WEBHOOK_SECRET
  header: X-Signature
  timestamp_header: X-Timestamp
  timestamp_tolerance: 600  # 10 minutes
  algorithm: sha256
  format: "algorithm=signature"  # produces "sha256=abc123..."
  payload_template: "{timestamp}:{body}"
```

**Example curl request:**

```bash
#!/bin/bash

# Configuration
WEBHOOK_URL="https://your-hooks-server.com/webhooks/generic"
SECRET="your_webhook_secret"
TIMESTAMP=$(date +%s)
PAYLOAD='{"event":"deployment","status":"success"}'

# Construct the signing payload (timestamp:body format)
SIGNING_PAYLOAD="${TIMESTAMP}:${PAYLOAD}"

# Generate HMAC signature
SIGNATURE=$(echo -n "$SIGNING_PAYLOAD" | openssl dgst -sha256 -hmac "$SECRET" -hex | cut -d' ' -f2)
FORMATTED_SIGNATURE="sha256=${SIGNATURE}"

# Send the request
curl -X POST "$WEBHOOK_URL" \
  -H "Content-Type: application/json" \
  -H "X-Signature: $FORMATTED_SIGNATURE" \
  -H "X-Timestamp: $TIMESTAMP" \
  -d "$PAYLOAD"
```

This approach provides strong security through timestamp validation while using a simpler format than the Slack-style implementation. The signing payload becomes `1609459200:{"event":"deployment","status":"success"}` and the resulting signature format is `sha256=computed_hmac_hash`.

**Tailscale-style HMAC with structured headers:**

This configuration supports providers like Tailscale that include both timestamp and signature in a single header using comma-separated key-value pairs.

```yaml
auth:
  type: hmac
  secret_env_key: TAILSCALE_WEBHOOK_SECRET
  header: Tailscale-Webhook-Signature
  algorithm: sha256
  format: "signature_only"  # produces "abc123..." (no prefix)
  header_format: "structured"  # enables parsing of "t=123,v1=abc" format
  signature_key: "v1"  # key for signature in structured header
  timestamp_key: "t"   # key for timestamp in structured header
  payload_template: "{timestamp}.{body}"  # dot-separated format
  timestamp_tolerance: 300  # 5 minutes
```

**How it works:**

1. The signature header contains both timestamp and signature: `Tailscale-Webhook-Signature: t=1663781880,v1=0123456789abcdef`
2. The timestamp and signature are extracted from the structured header
3. The HMAC is calculated over the payload using the template: `{timestamp}.{body}`
4. For example, if timestamp is "1663781880" and body is `{"event":"test"}`, the signed payload becomes: `1663781880.{"event":"test"}`
5. The signature is validated as a raw hex string (no prefix)

**Example curl request:**

```bash
#!/bin/bash

# Configuration
WEBHOOK_URL="https://your-hooks-server.com/webhooks/tailscale"
SECRET="your_tailscale_webhook_secret"
TIMESTAMP=$(date +%s)
PAYLOAD='{"nodeId":"n123","event":"nodeCreated"}'

# Construct the signing payload (timestamp.body format)
SIGNING_PAYLOAD="${TIMESTAMP}.${PAYLOAD}"

# Generate HMAC signature
SIGNATURE=$(echo -n "$SIGNING_PAYLOAD" | openssl dgst -sha256 -hmac "$SECRET" -hex | cut -d' ' -f2)
STRUCTURED_SIGNATURE="t=${TIMESTAMP},v1=${SIGNATURE}"

# Send the request
curl -X POST "$WEBHOOK_URL" \
  -H "Content-Type: application/json" \
  -H "Tailscale-Webhook-Signature: $STRUCTURED_SIGNATURE" \
  -d "$PAYLOAD"
```

This format is particularly useful for providers that want to include multiple pieces of metadata in a single header while maintaining strong security through timestamp validation.

### Shared Secret Authentication

The SharedSecret plugin provides simple secret-based authentication by comparing a secret value sent in an HTTP header. While simpler than HMAC, it provides less security since the secret is transmitted directly in the request header.

**Type:** `shared_secret`

#### Shared Secret Configuration Options

##### `secret_env_key` (required for shared secrets)

The name of the environment variable containing the shared secret for validation.

**Example:** `WEBHOOK_SECRET`

##### `header` (contains the shared secret)

The HTTP header where the shared secret is transmitted.

**Default:** `Authorization`  
**Example:** `X-API-Key`

#### Shared Secret Examples

**Basic shared secret with Authorization header:**

```yaml
auth:
  type: shared_secret
  secret_env_key: WEBHOOK_SECRET
  header: Authorization
```

**Custom header shared secret:**

```yaml
auth:
  type: shared_secret
  secret_env_key: API_KEY_SECRET
  header: X-API-Key
```

## Custom Auth Plugins

This section provides an example of how to implement a custom authentication plugin for a hypothetical system. The plugin checks for a specific authorization header and validates it against a secret stored in an environment variable.

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

Here is a mini example of how you might do some sort of IP filtering in a custom auth plugin:

```ruby
# frozen_string_literal: true
# Example custom auth plugin for IP filtering
module Hooks
  module Plugins
    module Auth
      class IpFilteringPlugin < Base
        def self.valid?(payload:, headers:, config:)
          # Get the allowed IPs from the configuration (opts is a hash containing additional options that can be set in any endpoint configuration)
          allowed_ips = config.dig(:opts, :allowed_ips) || []

          # Get the request IP from headers or payload
          # Find the IP via the request headers with case-insensitive matching - this is a helper method available in the base class
          # so it is available to all auth plugins.
          # This example assumes the IP is in the "X-Forwarded-For" header, which is common for proxied requests
          request_ip = find_header_value(headers, "X-Forwarded-For")

          # If the request IP is not found, return false
          return false unless request_ip

          # Return true if the request IP is in the allowed IPs list
          allowed_ips.include?(request_ip)
        end
      end
    end
  end
end
```
