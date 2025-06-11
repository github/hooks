# frozen_string_literal: true

require "rack/test"

describe Hooks::App::HealthEndpoint do
  include Rack::Test::Methods

  def app
    described_class
  end

  before do
    # Mock API start_time for consistent uptime calculation
    allow(Hooks::App::API).to receive(:start_time).and_return(Time.parse("2024-12-31T23:59:00Z"))
  end

  describe "GET /" do
    it "returns health status as JSON" do
      get "/"

      expect(last_response.status).to eq(200)
      expect(last_response.headers["Content-Type"]).to include("application/json")
    end

    it "includes health status in response" do
      get "/"

      response_data = JSON.parse(last_response.body)
      expect(response_data["status"]).to eq("healthy")
    end

    it "includes timestamp in ISO8601 format" do
      get "/"

      response_data = JSON.parse(last_response.body)
      expect(response_data["timestamp"]).to eq(TIME_MOCK)
    end

    it "includes version information" do
      get "/"

      response_data = JSON.parse(last_response.body)
      expect(response_data["version"]).to eq(Hooks::VERSION)
    end

    it "includes uptime in seconds" do
      get "/"

      response_data = JSON.parse(last_response.body)
      expect(response_data["uptime_seconds"]).to be_a(Integer)
      expect(response_data["uptime_seconds"]).to eq(60) # 1 minute difference
    end

    it "returns valid JSON structure" do
      get "/"

      expect { JSON.parse(last_response.body) }.not_to raise_error

      response_data = JSON.parse(last_response.body)
      expect(response_data).to have_key("status")
      expect(response_data).to have_key("timestamp")
      expect(response_data).to have_key("version")
      expect(response_data).to have_key("uptime_seconds")
    end

    it "calculates uptime correctly" do
      # Test with different start time
      different_start = Time.parse("2024-12-31T23:58:30Z")
      allow(Hooks::App::API).to receive(:start_time).and_return(different_start)

      get "/"

      response_data = JSON.parse(last_response.body)
      expect(response_data["uptime_seconds"]).to eq(90) # 1.5 minutes difference
    end
  end
end
