#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative "../lib/hooks"

puts "Testing Hooks framework..."

begin
  # Test basic instantiation
  puts "Creating Hooks app..."
  app = Hooks.build
  puts "✓ App created successfully"
  puts "App class: #{app.class}"

  # Test with config
  puts "\nTesting with config file..."
  app_with_config = Hooks.build(config: "./config/config.yaml")
  puts "✓ App with config created successfully"

rescue => e
  puts "✗ Error: #{e.class}: #{e.message}"
  puts e.backtrace.first(5).join("\n")
end
