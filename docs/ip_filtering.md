# IP Filtering

The Hooks service provides comprehensive application-level IP filtering functionality that allows you to control access to your webhooks based on client IP addresses. This feature supports both allowlist (whitelist) and blocklist (blacklist) configurations with CIDR notation support.

## Overview

IP filtering operates as a "pre-flight" check in the request processing pipeline, validating incoming requests before they reach your webhook handlers. The filtering can be configured both globally (for all endpoints) and at the individual endpoint level.

## ⚠️ Security Considerations

**Important**: This IP filtering operates at the application layer and relies on HTTP headers (like `X-Forwarded-For`) to determine client IP addresses. This approach has important security implications:

1. **Header Trust**: The service trusts proxy headers, which can be spoofed by malicious clients
2. **Network-Level Protection**: For production security, consider implementing IP filtering at the network or load balancer level
3. **Proper Proxy Configuration**: Ensure your reverse proxy/load balancer is properly configured to set accurate IP headers
4. **Defense in Depth**: Use this feature as part of a broader security strategy, not as the sole protection mechanism

## Configuration

### Global Configuration

Configure IP filtering globally to apply rules to all endpoints:

```yaml
# hooks.yml or your main configuration file
ip_filtering:
  ip_header: X-Forwarded-For  # Optional, defaults to X-Forwarded-For
  allowlist:
    - "10.0.0.0/8"           # Allow entire private network
    - "172.16.0.0/12"        # Allow another private range
    - "192.168.1.100"        # Allow specific IP
  blocklist:
    - "192.168.1.200"        # Block specific IP even if in allowlist
    - "203.0.113.0/24"       # Block entire subnet
```

### Endpoint-Level Configuration

Configure IP filtering for specific endpoints:

```yaml
# config/endpoints/secure-endpoint.yml
path: /secure-webhook
handler: my_secure_handler

ip_filtering:
  ip_header: X-Real-IP       # Optional, defaults to X-Forwarded-For
  allowlist:
    - "127.0.0.1"           # Allow localhost
    - "192.168.1.0/24"      # Allow local network
  blocklist:
    - "192.168.1.100"       # Block specific IP in the allowed range
```

## Configuration Options

### `ip_header` (optional)
- **Default**: `X-Forwarded-For`
- **Description**: HTTP header to check for the client IP address
- **Common alternatives**: `X-Real-IP`, `CF-Connecting-IP`, `X-Client-IP`

### `allowlist` (optional)
- **Type**: Array of strings
- **Description**: List of allowed IP addresses or CIDR ranges
- **Behavior**: If specified, only IPs in this list are allowed access
- **Format**: Individual IPs (`192.168.1.1`) or CIDR notation (`192.168.1.0/24`)

### `blocklist` (optional)
- **Type**: Array of strings
- **Description**: List of blocked IP addresses or CIDR ranges
- **Behavior**: IPs in this list are denied access, even if they appear in the allowlist
- **Format**: Individual IPs (`192.168.1.1`) or CIDR notation (`192.168.1.0/24`)

## Filtering Logic

The IP filtering follows this precedence order:

1. **Extract Client IP**: Get the client IP from the configured header (case-insensitive lookup)
2. **Check Blocklist**: If the IP matches any entry in the blocklist, deny immediately
3. **Check Allowlist**: If an allowlist is configured, the IP must match an entry to be allowed
4. **Default Allow**: If no allowlist is configured and IP is not blocked, allow the request

### Precedence Rules

- **Endpoint-level configuration** takes precedence over global configuration
- **Blocklist rules** take precedence over allowlist rules
- **First IP in comma-separated list** is used (e.g., in `X-Forwarded-For: 192.168.1.1, 10.0.0.1`, only `192.168.1.1` is checked)

## CIDR Notation Support

The service supports CIDR (Classless Inter-Domain Routing) notation for specifying IP ranges:

```yaml
ip_filtering:
  allowlist:
    - "192.168.1.0/24"      # Allows 192.168.1.1 through 192.168.1.254
    - "10.0.0.0/8"          # Allows 10.0.0.1 through 10.255.255.254
    - "172.16.0.0/12"       # Allows 172.16.0.1 through 172.31.255.254
  blocklist:
    - "192.168.1.100/32"    # Blocks specific IP (equivalent to 192.168.1.100)
    - "203.0.113.0/24"      # Blocks entire test network range
```

## Examples

### Example 1: Basic Allowlist

```yaml
# Allow only specific IPs
path: /secure-webhook
handler: secure_handler

ip_filtering:
  allowlist:
    - "127.0.0.1"
    - "192.168.1.50"
```

### Example 2: CIDR Range with Exceptions

```yaml
# Allow local network but block specific troublemaker
path: /internal-webhook
handler: internal_handler

ip_filtering:
  allowlist:
    - "192.168.1.0/24"
  blocklist:
    - "192.168.1.100"  # Block this specific IP
```

### Example 3: Custom IP Header

```yaml
# Use Cloudflare's connecting IP header
path: /cloudflare-webhook
handler: cf_handler

ip_filtering:
  ip_header: CF-Connecting-IP
  allowlist:
    - "203.0.113.0/24"
```

### Example 4: Multiple CIDR Ranges

```yaml
# Allow multiple office networks
path: /office-webhook
handler: office_handler

ip_filtering:
  allowlist:
    - "192.168.1.0/24"    # Main office
    - "192.168.2.0/24"    # Branch office
    - "10.0.100.0/24"     # VPN range
  blocklist:
    - "192.168.1.200"     # Compromised machine
```

## Error Responses

When IP filtering fails, the service returns an HTTP 403 Forbidden response:

```json
{
  "error": "ip_filtering_failed",
  "message": "IP address not allowed",
  "request_id": "550e8400-e29b-41d4-a716-446655440000"
}
```

## Testing Your Configuration

You can test your IP filtering configuration using curl:

```bash
# Test with allowed IP
curl -H "X-Forwarded-For: 192.168.1.50" \
     -H "Content-Type: application/json" \
     -d '{"test": "data"}' \
     http://localhost:8080/webhooks/secure-endpoint

# Test with blocked IP
curl -H "X-Forwarded-For: 192.168.1.100" \
     -H "Content-Type: application/json" \
     -d '{"test": "data"}' \
     http://localhost:8080/webhooks/secure-endpoint
```

## Common Use Cases

### 1. Restrict to Corporate Network

```yaml
ip_filtering:
  allowlist:
    - "10.0.0.0/8"        # Private network
    - "172.16.0.0/12"     # Private network
    - "192.168.0.0/16"    # Private network
```

### 2. Allow Specific Service Providers

```yaml
ip_filtering:
  allowlist:
    - "140.82.112.0/20"   # GitHub webhook IPs (example)
    - "192.30.252.0/22"   # GitHub webhook IPs (example)
```

### 3. Block Known Bad Actors

```yaml
ip_filtering:
  blocklist:
    - "203.0.113.0/24"    # Example bad network
    - "198.51.100.50"     # Specific bad IP
```

### 4. Development vs Production

```yaml
# Development - allow local testing
ip_filtering:
  allowlist:
    - "127.0.0.1"
    - "192.168.1.0/24"

# Production - restrict to known sources
ip_filtering:
  allowlist:
    - "10.0.0.0/8"
  blocklist:
    - "10.0.0.100"  # Compromised internal host
```

## Best Practices

1. **Start Restrictive**: Begin with a narrow allowlist and expand as needed
2. **Monitor Logs**: Watch for legitimate traffic being blocked
3. **Layer Security**: Use IP filtering alongside other security measures
4. **Document Changes**: Keep track of why specific IPs or ranges are allowed/blocked
5. **Regular Review**: Periodically review and update your IP filtering rules
6. **Test Thoroughly**: Always test configuration changes in a non-production environment first
7. **Consider Automation**: For dynamic environments, consider using network-level controls instead

## Troubleshooting

### Common Issues

1. **Wrong IP Header**: Verify your proxy/load balancer sets the correct IP header
2. **CIDR Notation**: Ensure CIDR ranges are correctly formatted
3. **Header Case**: The service performs case-insensitive header lookup
4. **Multiple IPs**: Only the first IP in comma-separated headers is checked
5. **IPv6 Support**: The service supports IPv6 addresses and ranges

### Debug Steps

1. Check server logs for IP filtering messages
2. Verify the client IP being detected matches expectations
3. Test with known good/bad IPs
4. Confirm endpoint vs global configuration precedence
5. Validate CIDR range calculations

## Performance Considerations

- IP filtering adds minimal overhead to request processing
- CIDR matching is optimized for common use cases
- Consider the number of rules - hundreds of rules may impact performance
- Invalid IP patterns in configuration are silently skipped

## Migration from Auth Plugins

If you're currently using custom auth plugins for IP filtering, you can migrate to the built-in IP filtering feature:

**Before (Custom Auth Plugin):**
```yaml
path: /webhook
handler: my_handler
auth:
  type: my_ip_filtering_plugin
opts:
  allowed_ips:
    - "192.168.1.1"
```

**After (Built-in IP Filtering):**
```yaml
path: /webhook
handler: my_handler
ip_filtering:
  allowlist:
    - "192.168.1.1"
```

The built-in IP filtering provides better performance, more features (CIDR support, blocklists), and consistent error handling across all endpoints.
