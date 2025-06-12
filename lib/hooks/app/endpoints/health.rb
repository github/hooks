# frozen_string_literal: true

require "grape"
require_relative "../../version"

module Hooks
  module App
    class HealthEndpoint < Grape::API
      get do
        content_type "application/json"
        {
          status: "healthy",
          timestamp: Time.now.utc.iso8601,
          version: Hooks::VERSION,
          uptime_seconds: (Time.now - Hooks::App::API.server_start_time).to_i
        }.to_json
      end
    end
  end
end
