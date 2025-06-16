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

  # Helper methods to reduce duplication
  def make_request(method, path, payload = nil, headers = {})
    case method
    when :get
      http.get(path, headers)
    when :post
      http.post(path, payload, headers)
    end
  end

  def expect_response(response, expected_type, expected_body_content = nil)
    expect(response).to be_a(expected_type)
    expect(response.body).to include(expected_body_content) if expected_body_content
  end

  def parse_json_response(response)
    JSON.parse(response.body)
  end

  def json_headers(additional_headers = {})
    { "Content-Type" => "application/json" }.merge(additional_headers)
  end

  def generate_hmac_signature(payload, secret, algorithm = "sha256", prefix = "sha256=")
    digest = OpenSSL::HMAC.hexdigest(OpenSSL::Digest.new(algorithm), secret, payload)
    "#{prefix}#{digest}"
  end

  def generate_hmac_with_timestamp(payload, secret, timestamp, algorithm = "sha256")
    signing_payload = "#{timestamp}:#{payload}"
    generate_hmac_signature(signing_payload, secret, algorithm)
  end

  def generate_slack_signature(payload, secret, timestamp)
    signing_payload = "v0:#{timestamp}:#{payload}"
    digest = OpenSSL::HMAC.hexdigest(OpenSSL::Digest.new("sha256"), secret, signing_payload)
    "v0=#{digest}"
  end

  def current_timestamp
    Time.now.utc.iso8601
  end

  def unix_timestamp
    Time.now.to_i.to_s
  end

  def expired_timestamp(seconds_ago = 600)
    (Time.now.utc - seconds_ago).iso8601
  end

  def expired_unix_timestamp(seconds_ago = 600)
    (Time.now.to_i - seconds_ago).to_s
  end

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
      response = make_request(:get, "/health")
      expect_response(response, Net::HTTPSuccess)

      body = parse_json_response(response)
      expect(body["status"]).to eq("healthy")
      expect(body["version"]).to eq(Hooks::VERSION)
      expect(body).to have_key("timestamp")
      expect(body).to have_key("uptime_seconds")
    end

    it "responds to the /version endpoint" do
      response = make_request(:get, "/version")
      expect_response(response, Net::HTTPSuccess)

      body = parse_json_response(response)
      expect(body["version"]).to eq(Hooks::VERSION)
      expect(body).to have_key("timestamp")
    end
  end

  describe "endpoints" do
    describe "team1" do
      it "responds to the /webhooks/team1 endpoint" do
        response = make_request(:get, "/webhooks/team1")
        expect_response(response, Net::HTTPMethodNotAllowed, "405 Not Allowed")
      end

      it "processes a POST request with JSON payload" do
        payload = { event: "test_event", data: "test_data", event_type: "alert" }
        response = make_request(:post, "/webhooks/team1", payload.to_json, json_headers)
        expect_response(response, Net::HTTPSuccess)

        body = parse_json_response(response)
        expect(body["status"]).to eq("alert_processed")
        expect(body["handler"]).to eq("Team1Handler")
        expect(body["channels_notified"]).to include("#team1-alerts")
        expect(body).to have_key("timestamp")
      end
    end

    describe "github" do
      it "receives a POST request but contains an invalid HMAC signature" do
        payload = { action: "push", repository: { name: "test-repo" } }
        headers = json_headers("X-Hub-Signature-256" => "sha256=invalidsignature")
        response = make_request(:post, "/webhooks/github", payload.to_json, headers)

        expect_response(response, Net::HTTPUnauthorized, "authentication failed")
      end

      it "receives a POST request but there is no HMAC related header" do
        payload = { action: "push", repository: { name: "test-repo" } }
        response = make_request(:post, "/webhooks/github", payload.to_json, json_headers)
        expect_response(response, Net::HTTPUnauthorized, "authentication failed")
      end

      it "receives a POST request but it uses the wrong algo" do
        payload = { action: "push", repository: { name: "test-repo" } }
        json_payload = payload.to_json
        signature = generate_hmac_signature(json_payload, FAKE_HMAC_SECRET, "sha512", "sha512=")
        headers = json_headers("X-Hub-Signature-256" => signature)
        response = make_request(:post, "/webhooks/github", json_payload, headers)
        expect_response(response, Net::HTTPUnauthorized, "authentication failed")
      end

      it "successfully processes a valid POST request with HMAC signature" do
        payload = { action: "push", repository: { name: "test-repo" } }
        json_payload = payload.to_json
        signature = generate_hmac_signature(json_payload, FAKE_HMAC_SECRET)
        headers = json_headers("X-Hub-Signature-256" => signature)
        response = make_request(:post, "/webhooks/github", json_payload, headers)
        expect_response(response, Net::HTTPSuccess)
        body = parse_json_response(response)
        expect(body["status"]).to eq("success")
      end
    end

    describe "hmac_with_timestamp" do
      it "successfully processes a valid POST request with HMAC signature and timestamp" do
        payload = { text: "Hello, World!" }
        timestamp = current_timestamp
        json_payload = payload.to_json
        signature = generate_hmac_with_timestamp(json_payload, FAKE_ALT_HMAC_SECRET, timestamp)
        headers = json_headers("X-HMAC-Signature" => signature, "X-HMAC-Timestamp" => timestamp)
        response = make_request(:post, "/webhooks/hmac_with_timestamp", json_payload, headers)
        expect_response(response, Net::HTTPSuccess)
        body = parse_json_response(response)
        expect(body["status"]).to eq("success")
      end

      it "successfully processes a valid POST request with HMAC signature and timestamp and an empty payload" do
        payload = {}
        timestamp = current_timestamp
        json_payload = payload.to_json
        signature = generate_hmac_with_timestamp(json_payload, FAKE_ALT_HMAC_SECRET, timestamp)
        headers = json_headers("X-HMAC-Signature" => signature, "X-HMAC-Timestamp" => timestamp)
        response = make_request(:post, "/webhooks/hmac_with_timestamp", json_payload, headers)
        expect_response(response, Net::HTTPSuccess)
        body = parse_json_response(response)
        expect(body["status"]).to eq("success")
      end

      it "successfully processes a valid POST request with HMAC signature and the POST has no body" do
        timestamp = current_timestamp
        signature = generate_hmac_with_timestamp("", FAKE_ALT_HMAC_SECRET, timestamp)
        headers = json_headers("X-HMAC-Signature" => signature, "X-HMAC-Timestamp" => timestamp)
        response = make_request(:post, "/webhooks/hmac_with_timestamp", nil, headers)
        expect_response(response, Net::HTTPSuccess)
        body = parse_json_response(response)
        expect(body["status"]).to eq("success")
      end

      it "fails due to using the wrong HMAC secret" do
        payload = { text: "Hello, World!" }
        timestamp = current_timestamp
        json_payload = payload.to_json
        signature = generate_hmac_with_timestamp(json_payload, "bad-hmac-secret", timestamp)
        headers = json_headers("X-HMAC-Signature" => signature, "X-HMAC-Timestamp" => timestamp)
        response = make_request(:post, "/webhooks/hmac_with_timestamp", json_payload, headers)
        expect_response(response, Net::HTTPUnauthorized, "authentication failed")
      end

      it "fails due to missing timestamp header" do
        payload = { text: "Hello, World!" }
        json_payload = payload.to_json
        signature = generate_hmac_with_timestamp(json_payload, FAKE_ALT_HMAC_SECRET, current_timestamp)
        headers = json_headers("X-HMAC-Signature" => signature)
        response = make_request(:post, "/webhooks/hmac_with_timestamp", json_payload, headers)
        expect_response(response, Net::HTTPUnauthorized, "authentication failed")
      end

      it "fails due to invalid timestamp format" do
        payload = { text: "Hello, World!" }
        invalid_timestamp = "not-a-timestamp"
        json_payload = payload.to_json
        signature = generate_hmac_with_timestamp(json_payload, FAKE_ALT_HMAC_SECRET, invalid_timestamp)
        headers = json_headers("X-HMAC-Signature" => signature, "X-HMAC-Timestamp" => invalid_timestamp)
        response = make_request(:post, "/webhooks/hmac_with_timestamp", json_payload, headers)
        expect_response(response, Net::HTTPUnauthorized, "authentication failed")
      end

      it "rejects request with timestamp manipulation attack" do
        payload = { text: "Hello, World!" }
        original_timestamp = current_timestamp
        manipulated_timestamp = (Time.now.utc + 100).iso8601
        json_payload = payload.to_json

        # Create signature with original timestamp but send manipulated timestamp
        signature = generate_hmac_with_timestamp(json_payload, FAKE_ALT_HMAC_SECRET, original_timestamp)
        headers = json_headers("X-HMAC-Signature" => signature, "X-HMAC-Timestamp" => manipulated_timestamp)
        response = make_request(:post, "/webhooks/hmac_with_timestamp", json_payload, headers)
        expect_response(response, Net::HTTPUnauthorized, "authentication failed")
      end

      it "fails because the timestamp is too old" do
        payload = { text: "Hello, World!" }
        expired_ts = expired_timestamp
        json_payload = payload.to_json
        signature = generate_hmac_with_timestamp(json_payload, FAKE_ALT_HMAC_SECRET, expired_ts)
        headers = json_headers("X-HMAC-Signature" => signature, "X-HMAC-Timestamp" => expired_ts)
        response = make_request(:post, "/webhooks/hmac_with_timestamp", json_payload, headers)
        expect_response(response, Net::HTTPUnauthorized, "authentication failed")
      end

      it "fails because the wrong HMAC algorithm is used" do
        payload = { text: "Hello, World!" }
        timestamp = current_timestamp
        json_payload = payload.to_json
        signature = generate_hmac_with_timestamp(json_payload, FAKE_ALT_HMAC_SECRET, timestamp, "sha512")
        signature = signature.gsub("sha256=", "sha512=")
        headers = json_headers("X-HMAC-Signature" => signature, "X-HMAC-Timestamp" => timestamp)
        response = make_request(:post, "/webhooks/hmac_with_timestamp", json_payload, headers)
        expect_response(response, Net::HTTPUnauthorized, "authentication failed")
      end
    end

    describe "slack" do
      it "successfully processes a valid POST request with HMAC signature and timestamp" do
        payload = { text: "Hello, Slack!" }
        timestamp = unix_timestamp
        json_payload = payload.to_json
        signature = generate_slack_signature(json_payload, FAKE_ALT_HMAC_SECRET, timestamp)
        headers = json_headers("Signature-256" => signature, "X-Timestamp" => timestamp)
        response = make_request(:post, "/webhooks/slack", json_payload, headers)
        expect_response(response, Net::HTTPSuccess)
        body = parse_json_response(response)
        expect(body["status"]).to eq("success")
      end

      it "rejects request with expired timestamp" do
        payload = { text: "Hello, Slack!" }
        expired_ts = expired_unix_timestamp
        json_payload = payload.to_json
        signature = generate_slack_signature(json_payload, FAKE_ALT_HMAC_SECRET, expired_ts)
        headers = json_headers("Signature-256" => signature, "X-Timestamp" => expired_ts)
        response = make_request(:post, "/webhooks/slack", json_payload, headers)
        expect_response(response, Net::HTTPUnauthorized, "authentication failed")
      end

      it "rejects request with missing timestamp header" do
        payload = { text: "Hello, Slack!" }
        timestamp = unix_timestamp
        json_payload = payload.to_json
        signature = generate_slack_signature(json_payload, FAKE_ALT_HMAC_SECRET, timestamp)
        headers = json_headers("Signature-256" => signature)
        response = make_request(:post, "/webhooks/slack", json_payload, headers)
        expect_response(response, Net::HTTPUnauthorized, "authentication failed")
      end

      it "rejects request with invalid timestamp format" do
        payload = { text: "Hello, Slack!" }
        invalid_timestamp = "not-a-timestamp"
        json_payload = payload.to_json
        signature = generate_slack_signature(json_payload, FAKE_ALT_HMAC_SECRET, invalid_timestamp)
        headers = json_headers("Signature-256" => signature, "X-Timestamp" => invalid_timestamp)
        response = make_request(:post, "/webhooks/slack", json_payload, headers)
        expect_response(response, Net::HTTPUnauthorized, "authentication failed")
      end

      it "successfully processes request with ISO 8601 UTC timestamp" do
        payload = { text: "Hello, Slack!" }
        iso_timestamp = Time.now.utc.strftime("%Y-%m-%dT%H:%M:%SZ")
        json_payload = payload.to_json
        signature = generate_slack_signature(json_payload, FAKE_ALT_HMAC_SECRET, iso_timestamp)
        headers = json_headers("Signature-256" => signature, "X-Timestamp" => iso_timestamp)
        response = make_request(:post, "/webhooks/slack", json_payload, headers)
        expect_response(response, Net::HTTPSuccess)
        body = parse_json_response(response)
        expect(body["status"]).to eq("success")
      end

      it "successfully processes request with ISO 8601 UTC timestamp (ruby default method)" do
        payload = { text: "Hello, Slack!" }
        iso_timestamp = current_timestamp
        json_payload = payload.to_json
        signature = generate_slack_signature(json_payload, FAKE_ALT_HMAC_SECRET, iso_timestamp)
        headers = json_headers("Signature-256" => signature, "X-Timestamp" => iso_timestamp)
        response = make_request(:post, "/webhooks/slack", json_payload, headers)
        expect_response(response, Net::HTTPSuccess)
        body = parse_json_response(response)
        expect(body["status"]).to eq("success")
      end

      it "successfully processes request with ISO 8601 UTC timestamp using +00:00 format" do
        payload = { text: "Hello, Slack!" }
        iso_timestamp = Time.now.utc.strftime("%Y-%m-%dT%H:%M:%S+00:00")
        json_payload = payload.to_json
        signature = generate_slack_signature(json_payload, FAKE_ALT_HMAC_SECRET, iso_timestamp)
        headers = json_headers("Signature-256" => signature, "X-Timestamp" => iso_timestamp)
        response = make_request(:post, "/webhooks/slack", json_payload, headers)
        expect_response(response, Net::HTTPSuccess)
        body = parse_json_response(response)
        expect(body["status"]).to eq("success")
      end

      it "rejects request with non-UTC ISO 8601 timestamp" do
        payload = { text: "Hello, Slack!" }
        non_utc_timestamp = Time.now.strftime("%Y-%m-%dT%H:%M:%S-05:00")
        json_payload = payload.to_json
        signature = generate_slack_signature(json_payload, FAKE_ALT_HMAC_SECRET, non_utc_timestamp)
        headers = json_headers("Signature-256" => signature, "X-Timestamp" => non_utc_timestamp)
        response = make_request(:post, "/webhooks/slack", json_payload, headers)
        expect_response(response, Net::HTTPUnauthorized, "authentication failed")
      end

      it "rejects request with timestamp manipulation attack" do
        payload = { text: "Hello, Slack!" }
        original_timestamp = unix_timestamp
        manipulated_timestamp = (Time.now.to_i + 100).to_s
        json_payload = payload.to_json

        # Create signature with original timestamp but send manipulated timestamp
        signature = generate_slack_signature(json_payload, FAKE_ALT_HMAC_SECRET, original_timestamp)
        headers = json_headers("Signature-256" => signature, "X-Timestamp" => manipulated_timestamp)
        response = make_request(:post, "/webhooks/slack", json_payload, headers)
        expect_response(response, Net::HTTPUnauthorized, "authentication failed")
      end
    end

    describe "okta" do
      it "receives a POST request but contains an invalid shared secret" do
        payload = { event: "user.login", user: { id: "12345" } }
        headers = json_headers("Authorization" => "badvalue")
        response = make_request(:post, "/webhooks/okta", payload.to_json, headers)
        expect_response(response, Net::HTTPUnauthorized, "authentication failed")
      end

      it "successfully processes a valid POST request with shared secret" do
        payload = { event: "user.login", user: { id: "12345" } }
        headers = json_headers("Authorization" => FAKE_SHARED_SECRET)
        response = make_request(:post, "/webhooks/okta", payload.to_json, headers)
        expect_response(response, Net::HTTPSuccess)
        body = parse_json_response(response)
        expect(body["status"]).to eq("success")
      end
    end

    describe "custom auth plugin" do

      it "successfully validates using a custom auth plugin" do
        payload = {}.to_json
        headers = { "Authorization" => "Bearer octoawesome-shared-secret", "Content-Type" => "application/json" }
        response = make_request(:post, "/webhooks/with_custom_auth_plugin?foo=bar&bar=baz", payload, headers)

        expect_response(response, Net::HTTPSuccess)
        body = parse_json_response(response)
        expect(body["status"]).to eq("test_success")
        expect(body["handler"]).to eq("TestHandler")
        expect(body["payload_received"]).to eq({})
        expect(body["env_received"]).to have_key("REQUEST_METHOD")

        env = body["env_received"]
        expect(env["hooks.request_id"]).to be_a(String)
        expect(env["hooks.handler"]).to eq("TestHandler")
        expect(env["hooks.endpoint_config"]).to be_a(Hash)
        expect(env["hooks.start_time"]).to be_a(String)
        expect(env["hooks.full_path"]).to eq("/webhooks/with_custom_auth_plugin")
        expect(env["HTTP_AUTHORIZATION"]).to eq("Bearer octoawesome-shared-secret")
        expect(env["CONTENT_TYPE"]).to eq("application/json")
        expect(env["CONTENT_LENGTH"]).to eq("2") # length of "{}"
        expect(env["QUERY_STRING"]).to eq("foo=bar&bar=baz")
      end

      it "rejects requests with invalid credentials using custom auth plugin" do
        payload = {}.to_json
        headers = { "Authorization" => "Bearer wrong-secret" }
        response = make_request(:post, "/webhooks/with_custom_auth_plugin", payload, headers)
        expect_response(response, Net::HTTPUnauthorized, "authentication failed")
      end

      it "rejects requests with missing credentials using custom auth plugin" do
        payload = {}.to_json
        headers = {}
        response = make_request(:post, "/webhooks/with_custom_auth_plugin", payload, headers)
        expect_response(response, Net::HTTPUnauthorized, "authentication failed")
      end
    end

    describe "boomtown" do
      it "sends a POST request to the /webhooks/boomtown endpoint and it explodes" do
        payload = {}.to_json
        headers = {}
        response = make_request(:post, "/webhooks/boomtown", payload, headers)
        expect_response(response, Net::HTTPInternalServerError, "Boomtown error occurred")
        body = parse_json_response(response)
        expect(body["error"]).to eq("server_error")
        expect(body["message"]).to eq("Boomtown error occurred")
        expect(body).to have_key("backtrace")
        expect(body["backtrace"]).to be_a(String)
        expect(body).to have_key("request_id")
        expect(body["request_id"]).to be_a(String)
        expect(body).to have_key("handler")
        expect(body["handler"]).to eq("Boomtown")
      end
    end

    describe "does_not_exist" do
      it "sends a POST request to the /webhooks/does_not_exist endpoint and it fails because the handler does not exist" do
        payload = {}.to_json
        headers = {}
        response = make_request(:post, "/webhooks/does_not_exist", payload, headers)
        expect_response(response, Net::HTTPInternalServerError, /Handler plugin 'DoesNotExist' not found/)
        body = parse_json_response(response)
        expect(body["error"]).to eq("server_error")
        expect(body["message"]).to match(
          /Handler plugin 'DoesNotExist' not found. Available handlers: DefaultHandler,.*/
        )
      end
    end

    describe "okta setup" do
      it "sends a POST request to the /webhooks/okta_webhook_setup endpoint and it fails because it is not a GET" do
        payload = {}.to_json
        headers = {}
        response = make_request(:post, "/webhooks/okta_webhook_setup", payload, headers)
        expect_response(response, Net::HTTPMethodNotAllowed, "405 Not Allowed")
      end

      it "sends a GET request to the /webhooks/okta_webhook_setup endpoint and it returns the verification challenge" do
        headers = { "x-okta-verification-challenge" => "test-challenge" }
        response = make_request(:get, "/webhooks/okta_webhook_setup", nil, headers)

        expect_response(response, Net::HTTPSuccess)
        body = parse_json_response(response)
        expect(body["verification"]).to eq("test-challenge")
      end

      it "sends a GET request to the /webhooks/okta_webhook_setup endpoint but it is missing the verification challenge header" do
        response = make_request(:get, "/webhooks/okta_webhook_setup")

        expect_response(response, Net::HTTPSuccess)
        expect(response.code).to eq("200")
        body = parse_json_response(response)
        expect(body["error"]).to eq("Missing verification challenge header")
        expect(body["expected_header"]).to eq("x-okta-verification-challenge")
      end
    end

    describe "boomtown_with_error" do
      it "sends a POST request to the /webhooks/boomtown_with_error endpoint and it does not explode" do
        payload = { boom: false }.to_json
        response = make_request(:post, "/webhooks/boomtown_with_error", payload, json_headers)
        expect_response(response, Net::HTTPSuccess)

        body = parse_json_response(response)
        expect(body["status"]).to eq("ok")
      end

      it "sends a POST request to the /webhooks/boomtown_with_error endpoint and it explodes" do
        payload = { boom: true }.to_json
        response = make_request(:post, "/webhooks/boomtown_with_error", payload, json_headers)
        expect_response(response, Net::HTTPInternalServerError, "the payload triggered a boomtown error")

        body = parse_json_response(response)
        expect(body["error"]).to eq("boomtown_with_error")
        expect(body["message"]).to eq("the payload triggered a boomtown error")
        expect(body).to have_key("request_id")
        expect(body["request_id"]).to be_a(String)
        expect(body["foo"]).to eq("bar")
        expect(body["truthy"]).to eq(true)
      end
    end
  end
end
