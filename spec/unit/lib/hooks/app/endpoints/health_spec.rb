# frozen_string_literal: true

describe Hooks::App::HealthEndpoint do
  # Test the endpoint behavior using a mock API instance
  let(:api_instance) do
    Class.new(Grape::API) do
      mount Hooks::App::HealthEndpoint
    end
  end

  before do
    # Mock the API start time
    allow(Hooks::App::API).to receive(:start_time).and_return(Time.parse("2025-01-01T00:00:00Z"))
  end

  describe "GET /" do
    let(:response) { api_instance.new.call(Rack::MockRequest.env_for("/")) }

    it "returns 200 status" do
      expect(response[0]).to eq(200)
    end

    it "returns JSON content type" do
      headers = response[1]
      expect(headers["Content-Type"]).to include("application/json")
    end

    it "returns health status information" do
      body = JSON.parse(response[2].first)

      expect(body["status"]).to eq("healthy")
      expect(body["timestamp"]).to eq(TIME_MOCK)
      expect(body["version"]).to eq(Hooks::VERSION)
      expect(body["uptime_seconds"]).to be_a(Integer)
      expect(body["uptime_seconds"]).to eq(0) # Since mocked time is the same as start time
    end

    it "calculates uptime correctly" do
      # Set different start time to test uptime calculation
      start_time = Time.parse("2024-12-31T23:59:30Z")
      allow(Hooks::App::API).to receive(:start_time).and_return(start_time)

      body = JSON.parse(response[2].first)
      expect(body["uptime_seconds"]).to eq(30) # 30 seconds difference
    end

    it "includes all required fields" do
      body = JSON.parse(response[2].first)

      expect(body).to have_key("status")
      expect(body).to have_key("timestamp")
      expect(body).to have_key("version")
      expect(body).to have_key("uptime_seconds")
    end

    it "returns valid JSON" do
      expect { JSON.parse(response[2].first) }.not_to raise_error
    end
  end

  describe "inheritance" do
    it "inherits from Grape::API" do
      expect(described_class.superclass).to eq(Grape::API)
    end
  end
end