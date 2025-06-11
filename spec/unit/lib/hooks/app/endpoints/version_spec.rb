# frozen_string_literal: true

describe Hooks::App::VersionEndpoint do
  # Test the endpoint behavior using a mock API instance
  let(:api_instance) do
    Class.new(Grape::API) do 
      mount Hooks::App::VersionEndpoint
    end
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

    it "returns version information" do
      body = JSON.parse(response[2].first)

      expect(body["version"]).to eq(Hooks::VERSION)
      expect(body["timestamp"]).to eq(TIME_MOCK)
    end

    it "includes all required fields" do
      body = JSON.parse(response[2].first)

      expect(body).to have_key("version")
      expect(body).to have_key("timestamp")
    end

    it "has exactly two fields" do
      body = JSON.parse(response[2].first)
      expect(body.keys.length).to eq(2)
    end

    it "returns valid JSON" do
      expect { JSON.parse(response[2].first) }.not_to raise_error
    end

    it "returns current version from Hooks::VERSION" do
      body = JSON.parse(response[2].first)
      expect(body["version"]).to match(/^\d+\.\d+\.\d+$/)
    end

    it "returns timestamp in ISO 8601 format" do
      body = JSON.parse(response[2].first)
      expect(body["timestamp"]).to match(/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z$/)
    end
  end

  describe "inheritance" do
    it "inherits from Grape::API" do
      expect(described_class.superclass).to eq(Grape::API)
    end
  end
end