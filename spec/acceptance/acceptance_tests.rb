# frozen_string_literal: true

FAKE_HMAC_SECRET = "octoawesome-secret"
FAKE_ALT_HMAC_SECRET = "octoawesome-2-secret"
FAKE_SHARED_SECRET = "octoawesome-shared-secret"

require "rspec"
require "net/http"
require "json"

MAX_WAIT_TIME = 30 # how long to wait for the server to start

describe "Hooks" do
  let(:http) { Net::HTTP.new("0.0.0.0", 8080) }

  before(:all) do
    start_time = Time.now
    loop do
      begin
        response = Net::HTTP.new("0.0.0.0", 8080).get("/health")
        break if response.is_a?(Net::HTTPSuccess)
      rescue Errno::ECONNREFUSED, SocketError, StandardError
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

    describe "github" do
      it "receives a POST request but contains an invalid HMAC signature" do
        payload = { action: "push", repository: { name: "test-repo" } }
        headers = { "Content-Type" => "application/json", "X-Hub-Signature-256" => "sha256=invalidsignature" }
        response = http.post("/webhooks/github", payload.to_json, headers)

        expect(response).to be_a(Net::HTTPUnauthorized)
        expect(response.body).to include("authentication failed")
      end

      it "receives a POST request but there is no HMAC related header" do
        payload = { action: "push", repository: { name: "test-repo" } }
        headers = { "Content-Type" => "application/json" }
        response = http.post("/webhooks/github", payload.to_json, headers)
        expect(response).to be_a(Net::HTTPUnauthorized)
        expect(response.body).to include("authentication failed")
      end

      it "receives a POST request but it uses the wrong algo" do
        payload = { action: "push", repository: { name: "test-repo" } }
        headers = {
          "Content-Type" => "application/json",
          "X-Hub-Signature-256" => "sha512=" + OpenSSL::HMAC.hexdigest(OpenSSL::Digest.new("sha512"), FAKE_HMAC_SECRET, payload.to_json)
        }
        response = http.post("/webhooks/github", payload.to_json, headers)
        expect(response).to be_a(Net::HTTPUnauthorized)
        expect(response.body).to include("authentication failed")
      end

      it "successfully processes a valid POST request with HMAC signature" do
        payload = { action: "push", repository: { name: "test-repo" } }
        headers = {
          "Content-Type" => "application/json",
          "X-Hub-Signature-256" => "sha256=" + OpenSSL::HMAC.hexdigest(OpenSSL::Digest.new("sha256"), FAKE_HMAC_SECRET, payload.to_json)
        }
        response = http.post("/webhooks/github", payload.to_json, headers)
        expect(response).to be_a(Net::HTTPSuccess)
        body = JSON.parse(response.body)
        expect(body["status"]).to eq("success")
      end
    end

    describe "slack" do
      it "receives a POST request but contains an invalid HMAC signature" do
        payload = { text: "Hello, Slack!" }
        digest = OpenSSL::HMAC.hexdigest(OpenSSL::Digest.new("sha256"), FAKE_ALT_HMAC_SECRET, payload.to_json)
        headers = { "Content-Type" => "application/json", "Signature-256" => "sha256=#{digest}" }
        response = http.post("/webhooks/slack", payload.to_json, headers)

        expect(response).to be_a(Net::HTTPUnauthorized)
        expect(response.body).to include("authentication failed")
      end
    end

    describe "okta" do
      it "receives a POST request but contains an invalid shared secret" do
        payload = { event: "user.login", user: { id: "12345" } }
        headers = { "Content-Type" => "application/json", "Authorization" => "badvalue" }
        response = http.post("/webhooks/okta", payload.to_json, headers)

        expect(response).to be_a(Net::HTTPUnauthorized)
        expect(response.body).to include("authentication failed")
      end

      it "successfully processes a valid POST request with shared secret" do
        payload = { event: "user.login", user: { id: "12345" } }
        headers = { "Content-Type" => "application/json", "Authorization" => FAKE_SHARED_SECRET }
        response = http.post("/webhooks/okta", payload.to_json, headers)

        expect(response).to be_a(Net::HTTPSuccess)
        body = JSON.parse(response.body)
        expect(body["status"]).to eq("success")
      end
    end
  end
end
