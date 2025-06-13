# frozen_string_literal: true

ENV["HOOKS_SILENCE_CONFIG_LOADER_MESSAGES"] = "true" # Silence config loader messages in tests

require_relative "../../lib/hooks"

describe "Header Normalization Integration" do
  let(:config) do
    {
      normalize_headers: true
    }
  end

  let(:headers) do
    {
      "Content-Type" => "application/json",
      "X-GitHub-Event" => "push",
      "User-Agent" => "test-agent",
      "Accept-Encoding" => "gzip, br"
    }
  end

  context "when normalize_headers is enabled (default)" do
    it "normalizes headers but keeps string keys" do
      processed_headers = config[:normalize_headers] ? Hooks::Utils::Normalize.headers(headers) : headers

      expect(processed_headers).to eq({
        "content-type" => "application/json",
        "x-github-event" => "push",
        "user-agent" => "test-agent",
        "accept-encoding" => "gzip, br"
      })
    end
  end

  context "when normalize_headers is disabled" do
    let(:config) do
      {
        normalize_headers: false
      }
    end

    it "passes headers through unchanged" do
      processed_headers = config[:normalize_headers] ? Hooks::Utils::Normalize.headers(headers) : headers

      expect(processed_headers).to eq(headers)
    end
  end
end
