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
      it "successfully processes a valid POST request with HMAC signature and timestamp" do
        payload = { text: "Hello, Slack!" }
        timestamp = Time.now.to_i.to_s
        body = payload.to_json
        signing_payload = "v0:#{timestamp}:#{body}"
        digest = OpenSSL::HMAC.hexdigest(OpenSSL::Digest.new("sha256"), FAKE_ALT_HMAC_SECRET, signing_payload)
        headers = {
          "Content-Type" => "application/json",
          "Signature-256" => "v0=#{digest}",
          "X-Timestamp" => timestamp
        }
        response = http.post("/webhooks/slack", body, headers)
        expect(response).to be_a(Net::HTTPSuccess)
        body = JSON.parse(response.body)
        expect(body["status"]).to eq("success")
      end

      it "rejects request with expired timestamp" do
        payload = { text: "Hello, Slack!" }
        # Use timestamp that's 10 minutes old (beyond the 5 minute tolerance)
        expired_timestamp = (Time.now.to_i - 600).to_s

        signing_payload = "v0:#{expired_timestamp}:#{payload.to_json}"
        digest = OpenSSL::HMAC.hexdigest(OpenSSL::Digest.new("sha256"), FAKE_ALT_HMAC_SECRET, signing_payload)

        headers = {
          "Content-Type" => "application/json",
          "Signature-256" => "v0=#{digest}",
          "X-Timestamp" => expired_timestamp
        }

        response = http.post("/webhooks/slack", payload.to_json, headers)
        expect(response).to be_a(Net::HTTPUnauthorized)
        expect(response.body).to include("authentication failed")
      end

      it "rejects request with missing timestamp header" do
        payload = { text: "Hello, Slack!" }
        timestamp = Time.now.to_i.to_s

        # Create signature with timestamp but don't include timestamp header
        signing_payload = "v0:#{timestamp}:#{payload.to_json}"
        digest = OpenSSL::HMAC.hexdigest(OpenSSL::Digest.new("sha256"), FAKE_ALT_HMAC_SECRET, signing_payload)

        headers = {
          "Content-Type" => "application/json",
          "Signature-256" => "v0=#{digest}"
          # Missing X-Timestamp header
        }

        response = http.post("/webhooks/slack", payload.to_json, headers)
        expect(response).to be_a(Net::HTTPUnauthorized)
        expect(response.body).to include("authentication failed")
      end

      it "rejects request with invalid timestamp format" do
        payload = { text: "Hello, Slack!" }
        invalid_timestamp = "not-a-timestamp"

        signing_payload = "v0:#{invalid_timestamp}:#{payload.to_json}"
        digest = OpenSSL::HMAC.hexdigest(OpenSSL::Digest.new("sha256"), FAKE_ALT_HMAC_SECRET, signing_payload)

        headers = {
          "Content-Type" => "application/json",
          "Signature-256" => "v0=#{digest}",
          "X-Timestamp" => invalid_timestamp
        }

        response = http.post("/webhooks/slack", payload.to_json, headers)
        expect(response).to be_a(Net::HTTPUnauthorized)
        expect(response.body).to include("authentication failed")
      end

      it "successfully processes request with ISO 8601 UTC timestamp" do
        payload = { text: "Hello, Slack!" }
        iso_timestamp = Time.now.utc.strftime("%Y-%m-%dT%H:%M:%SZ")
        body = payload.to_json
        signing_payload = "v0:#{iso_timestamp}:#{body}"
        digest = OpenSSL::HMAC.hexdigest(OpenSSL::Digest.new("sha256"), FAKE_ALT_HMAC_SECRET, signing_payload)
        headers = {
          "Content-Type" => "application/json",
          "Signature-256" => "v0=#{digest}",
          "X-Timestamp" => iso_timestamp
        }
        response = http.post("/webhooks/slack", body, headers)
        expect(response).to be_a(Net::HTTPSuccess)
        body = JSON.parse(response.body)
        expect(body["status"]).to eq("success")
      end

      it "successfully processes request with ISO 8601 UTC timestamp using +00:00 format" do
        payload = { text: "Hello, Slack!" }
        iso_timestamp = Time.now.utc.strftime("%Y-%m-%dT%H:%M:%S+00:00")
        body = payload.to_json
        signing_payload = "v0:#{iso_timestamp}:#{body}"
        digest = OpenSSL::HMAC.hexdigest(OpenSSL::Digest.new("sha256"), FAKE_ALT_HMAC_SECRET, signing_payload)
        headers = {
          "Content-Type" => "application/json",
          "Signature-256" => "v0=#{digest}",
          "X-Timestamp" => iso_timestamp
        }
        response = http.post("/webhooks/slack", body, headers)
        expect(response).to be_a(Net::HTTPSuccess)
        body = JSON.parse(response.body)
        expect(body["status"]).to eq("success")
      end

      it "rejects request with non-UTC ISO 8601 timestamp" do
        payload = { text: "Hello, Slack!" }
        # Use EST timezone (non-UTC)
        non_utc_timestamp = Time.now.strftime("%Y-%m-%dT%H:%M:%S-05:00")

        signing_payload = "v0:#{non_utc_timestamp}:#{payload.to_json}"
        digest = OpenSSL::HMAC.hexdigest(OpenSSL::Digest.new("sha256"), FAKE_ALT_HMAC_SECRET, signing_payload)

        headers = {
          "Content-Type" => "application/json",
          "Signature-256" => "v0=#{digest}",
          "X-Timestamp" => non_utc_timestamp
        }

        response = http.post("/webhooks/slack", payload.to_json, headers)
        expect(response).to be_a(Net::HTTPUnauthorized)
        expect(response.body).to include("authentication failed")
      end

      it "rejects request with timestamp manipulation attack" do
        payload = { text: "Hello, Slack!" }
        original_timestamp = Time.now.to_i.to_s
        manipulated_timestamp = (Time.now.to_i + 100).to_s  # Future timestamp

        # Create signature with original timestamp
        signing_payload = "v0:#{original_timestamp}:#{payload.to_json}"
        digest = OpenSSL::HMAC.hexdigest(OpenSSL::Digest.new("sha256"), FAKE_ALT_HMAC_SECRET, signing_payload)

        # But send manipulated timestamp in header
        headers = {
          "Content-Type" => "application/json",
          "Signature-256" => "v0=#{digest}",
          "X-Timestamp" => manipulated_timestamp
        }

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

    describe "custom auth plugin" do

      it "successfully validates using a custom auth plugin" do
        payload = {}.to_json
        headers = { "Authorization" => "Bearer octoawesome-shared-secret" }
        response = http.post("/webhooks/with_custom_auth_plugin", payload, headers)

        expect(response).to be_a(Net::HTTPSuccess)
        body = JSON.parse(response.body)
        expect(body["status"]).to eq("test_success")
        expect(body["handler"]).to eq("TestHandler")
      end

      it "rejects requests with invalid credentials using custom auth plugin" do
        payload = {}.to_json
        headers = { "Authorization" => "Bearer wrong-secret" }
        response = http.post("/webhooks/with_custom_auth_plugin", payload, headers)

        expect(response).to be_a(Net::HTTPUnauthorized)
        expect(response.body).to include("authentication failed")
      end

      it "rejects requests with missing credentials using custom auth plugin" do
        payload = {}.to_json
        headers = {}
        response = http.post("/webhooks/with_custom_auth_plugin", payload, headers)

        expect(response).to be_a(Net::HTTPUnauthorized)
        expect(response.body).to include("authentication failed")
      end
    end

    describe "boomtown" do
      it "sends a POST request to the /webhooks/boomtown endpoint and it explodes" do
        payload = {}.to_json
        headers = {}
        response = http.post("/webhooks/boomtown", payload, headers)

        expect(response).to be_a(Net::HTTPInternalServerError)
        expect(response.body).to include("Boomtown error occurred")
      end
    end

    describe "okta setup" do
      it "sends a POST request to the /webhooks/okta_webhook_setup endpoint and it fails because it is not a GET" do
        payload = {}.to_json
        headers = {}
        response = http.post("/webhooks/okta_webhook_setup", payload, headers)

        expect(response).to be_a(Net::HTTPMethodNotAllowed)
        expect(response.body).to include("405 Not Allowed")
      end

      it "sends a GET request to the /webhooks/okta_webhook_setup endpoint and it returns the verification challenge" do
        headers = { "x-okta-verification-challenge" => "test-challenge" }
        response = http.get("/webhooks/okta_webhook_setup", headers)

        expect(response).to be_a(Net::HTTPSuccess)
        body = JSON.parse(response.body)
        expect(body["verification"]).to eq("test-challenge")
      end

      it "sends a GET request to the /webhooks/okta_webhook_setup endpoint but it is missing the verification challenge header" do
        response = http.get("/webhooks/okta_webhook_setup")

        expect(response).to be_a(Net::HTTPSuccess)
        expect(response.code).to eq("200")
        body = JSON.parse(response.body)
        expect(body["error"]).to eq("Missing verification challenge header")
        expect(body["expected_header"]).to eq("x-okta-verification-challenge")
      end
    end
  end
end
