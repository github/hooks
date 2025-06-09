# frozen_string_literal: true

require "rspec"
require "net/http"
require "json"

MAX_WAIT_TIME = 30 # how long to wait for the server to start

describe "Hooks" do
  let(:http) { Net::HTTP.new("127.0.0.1", 8080) }

  before(:all) do
    start_time = Time.now
    loop do
      begin
        response = Net::HTTP.new("127.0.0.1", 8080).get("/health")
        break if response.is_a?(Net::HTTPSuccess)
      rescue Errno::ECONNREFUSED, SocketError
        # Server not ready yet, continue waiting
      end

      if Time.now - start_time > MAX_WAIT_TIME
        raise "Server did not return a 200 within #{MAX_WAIT_TIME} seconds"
      end

      sleep 1
    end
  end

  describe "operational endpoints" do
    it "responds to the /health check" do
      response = http.get("/health")
      expect(response).to be_a(Net::HTTPSuccess)

      body = JSON.parse(response.body)
      expect(body["status"]).to eq("healthy")
      expect(body["version"]).to eq(Hooks::VERSION)
      expect(body).to have_key("timestamp")
      expect(body).to have_key("uptime_seconds")
    end

    it "responds to the /version endpoint" do
      response = http.get("/version")
      expect(response).to be_a(Net::HTTPSuccess)

      body = JSON.parse(response.body)
      expect(body["version"]).to eq(Hooks::VERSION)
      expect(body).to have_key("timestamp")
    end
  end

  describe "endpoints" do
    describe "team1" do
      it "responds to the /webhooks/team1 endpoint" do
        response = http.get("/webhooks/team1")
        expect(response).to be_a(Net::HTTPMethodNotAllowed)
        expect(response.body).to include("405 Not Allowed")
      end

      it "processes a POST request with JSON payload" do
        payload = { event: "test_event", data: "test_data", event_type: "alert" }
        response = http.post("/webhooks/team1", payload.to_json, { "Content-Type" => "application/json" })
        expect(response).to be_a(Net::HTTPSuccess)

        body = JSON.parse(response.body)
        expect(body["status"]).to eq("alert_processed")
        expect(body["handler"]).to eq("Team1Handler")
        expect(body["channels_notified"]).to include("#team1-alerts")
        expect(body).to have_key("timestamp")
      end
    end
  end
end
