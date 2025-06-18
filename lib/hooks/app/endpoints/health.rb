# frozen_string_literal: true

require "grape"
require_relative "../../version"

module Hooks
  module App
    class HealthEndpoint < Grape::API
      # Set up content types and default format to JSON
      content_type :json, "application/json"
      content_type :txt, "text/plain"
      content_type :xml, "application/xml"
      content_type :any, "*/*"
      format :json
      default_format :json

      get do
        {
          status: "healthy",
          timestamp: Time.now.utc.iso8601,
          version: Hooks::VERSION,
          uptime_seconds: (Time.now - Hooks::App::API.server_start_time).to_i
        }
      end
    end
  end
end
