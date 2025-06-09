# frozen_string_literal: true

require_relative "lib/hooks"

# Build the Hooks application with default config
app = Hooks.build(config: "./config/config.yaml")

# Run the application
run app
