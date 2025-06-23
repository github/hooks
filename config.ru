# frozen_string_literal: true

# An example file that is a part of the acceptance tests for the Hooks framework.
# This can be used as a reference point as it is a working implementation of a Hooks application.

require_relative "lib/hooks"

# Example publisher class that simulates publishing messages
# This class could be literally anything and it is used here to demonstrate how to pass in custom kwargs...
# ... to the Hooks application which later become available in Handlers throughout the application.
class ExamplePublisher
  def initialize
    @published_messages = []
  end

  def call(data)
    @published_messages << data
    puts "Published: #{data.inspect}"
    "Message published successfully"
  end

  def publish(data)
    call(data)
  end

  def messages
    @published_messages
  end
end

# Create publisher instance
publisher = ExamplePublisher.new

# Create and run the hooks application with custom publisher
app = Hooks.build(config: "./spec/acceptance/config/hooks.yaml", publisher:)
run app
