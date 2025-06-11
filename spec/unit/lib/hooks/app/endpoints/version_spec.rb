# frozen_string_literal: true

require "rack/test"

describe Hooks::App::VersionEndpoint do
  include Rack::Test::Methods

  def app
    described_class
  end

  describe "GET /" do
    it "returns version information as JSON" do
      get "/"

      expect(last_response.status).to eq(200)
      expect(last_response.headers["Content-Type"]).to include("application/json")
    end

    it "includes version number in response" do
      get "/"
      
      response_data = JSON.parse(last_response.body)
      expect(response_data["version"]).to eq(Hooks::VERSION)
    end

    it "includes timestamp in ISO8601 format" do
      get "/"
      
      response_data = JSON.parse(last_response.body)
      expect(response_data["timestamp"]).to eq(TIME_MOCK)
    end

    it "returns valid JSON structure" do
      get "/"
      
      expect { JSON.parse(last_response.body) }.not_to raise_error
      
      response_data = JSON.parse(last_response.body)
      expect(response_data).to have_key("version")
      expect(response_data).to have_key("timestamp")
    end

    it "version matches expected format" do
      get "/"
      
      response_data = JSON.parse(last_response.body)
      expect(response_data["version"]).to match(/^\d+\.\d+\.\d+$/)
    end
  end
end