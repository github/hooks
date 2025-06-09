#!/usr/bin/env ruby
# frozen_string_literal: true

# Demo script to test the Hooks webhook server

require_relative "../lib/hooks"
require "net/http"
require "json"
require "uri"

puts "🪝 Hooks Webhook Server Demo"
puts "=" * 40

# Create a simple test config
test_config = {
  handler_dir: "./handlers",
  log_level: "info",
  request_limit: 1048576,
  request_timeout: 15,
  root_path: "/webhooks",
  health_path: "/health",
  version_path: "/version",
  environment: "development",
  endpoints_dir: "./config/endpoints"
}

puts "Building Hooks application..."
app = Hooks.build(config: test_config)

puts "✅ Application built successfully!"
puts "📊 Version: #{Hooks::VERSION}"

# Test with a simple Rack request
puts "\n🧪 Testing operational endpoints..."

# Create a simple mock request environment
def mock_request(method, path, body = nil, headers = {})
  env = {
    "REQUEST_METHOD" => method,
    "PATH_INFO" => path,
    "SCRIPT_NAME" => "",
    "QUERY_STRING" => "",
    "SERVER_NAME" => "localhost",
    "SERVER_PORT" => "3000",
    "rack.version" => [1, 3],
    "rack.url_scheme" => "http",
    "rack.input" => StringIO.new(body || ""),
    "rack.errors" => $stderr,
    "rack.multithread" => false,
    "rack.multiprocess" => true,
    "rack.run_once" => false
  }

  headers.each { |k, v| env["HTTP_#{k.upcase.gsub('-', '_')}"] = v }
  env
end

# Test health endpoint
puts "Testing /health..."
begin
  status, headers, body = app.call(mock_request("GET", "/health"))
  response_body = body.join("")
  parsed = JSON.parse(response_body)
  puts "  Status: #{status}"
  puts "  Response: #{parsed['status']} (v#{parsed['version']})"
rescue => e
  puts "  ❌ Error: #{e.message}"
end

# Test version endpoint
puts "\nTesting /version..."
begin
  status, headers, body = app.call(mock_request("GET", "/version"))
  response_body = body.join("")
  parsed = JSON.parse(response_body)
  puts "  Status: #{status}"
  puts "  Version: #{parsed['version']}"
rescue => e
  puts "  ❌ Error: #{e.message}"
end

# Test hello endpoint
puts "\nTesting /webhooks/hello..."
begin
  status, headers, body = app.call(mock_request("GET", "/webhooks/hello"))
  response_body = body.join("")
  parsed = JSON.parse(response_body)
  puts "  Status: #{status}"
  puts "  Message: #{parsed['message']}"
rescue => e
  puts "  ❌ Error: #{e.message}"
end

# Test webhook endpoint with default handler
puts "\nTesting /webhooks/demo with default handler..."
begin
  test_payload = { event: "demo", timestamp: Time.now.iso8601 }
  status, headers, body = app.call(mock_request(
    "POST",
    "/webhooks/demo",
    test_payload.to_json,
    { "Content-Type" => "application/json" }
  ))
  response_body = body.join("")
  parsed = JSON.parse(response_body)
  puts "  Status: #{status}"
  puts "  Handler: #{parsed['handler']}"
  puts "  Message: #{parsed['message']}"
rescue => e
  puts "  ❌ Error: #{e.message}"
end

puts "\n✅ Demo completed!"
puts "\n🚀 To start the server:"
puts "   ./bin/hooks serve -p 3000 -c ./config/config.yaml"
puts "\n📚 Example webhook endpoints:"
puts "   POST http://localhost:3000/webhooks/team1"
puts "   POST http://localhost:3000/webhooks/github"
puts "   GET  http://localhost:3000/health"
