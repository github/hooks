# frozen_string_literal: true

require "grape"
require_relative "../../version"

module Hooks
  module App
    class VersionEndpoint < Grape::API
      get do
        content_type "application/json"
        {
          version: Hooks::VERSION,
          timestamp: Time.now.iso8601
        }.to_json
      end
    end
  end
end
