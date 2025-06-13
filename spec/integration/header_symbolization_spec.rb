# frozen_string_literal: true

ENV["HOOKS_SILENCE_CONFIG_LOADER_MESSAGES"] = "true" # Silence config loader messages in tests

require_relative "../../lib/hooks"

describe "Header Symbolization Integration" do
  let(:config) do
    {
      symbolize_headers: true,
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

  context "when symbolize_headers is enabled (default)" do
    it "normalizes and symbolizes headers" do
      normalized_headers = config[:normalize_headers] ? Hooks::Utils::Normalize.headers(headers) : headers
      symbolized_headers = config[:symbolize_headers] ? Hooks::Utils::Normalize.symbolize_headers(normalized_headers) : normalized_headers

      expect(symbolized_headers).to eq({
        content_type: "application/json",
        x_github_event: "push",
        user_agent: "test-agent",
        accept_encoding: "gzip, br"
      })
    end
  end

  context "when symbolize_headers is disabled" do
    let(:config) do
      {
        symbolize_headers: false,
        normalize_headers: true
      }
    end

    it "normalizes but does not symbolize headers" do
      normalized_headers = config[:normalize_headers] ? Hooks::Utils::Normalize.headers(headers) : headers
      symbolized_headers = config[:symbolize_headers] ? Hooks::Utils::Normalize.symbolize_headers(normalized_headers) : normalized_headers

      expect(symbolized_headers).to eq({
        "content-type" => "application/json",
        "x-github-event" => "push",
        "user-agent" => "test-agent",
        "accept-encoding" => "gzip, br"
      })
    end
  end

  context "when both symbolize_headers and normalize_headers are disabled" do
    let(:config) do
      {
        symbolize_headers: false,
        normalize_headers: false
      }
    end

    it "passes headers through unchanged" do
      normalized_headers = config[:normalize_headers] ? Hooks::Utils::Normalize.headers(headers) : headers
      symbolized_headers = config[:symbolize_headers] ? Hooks::Utils::Normalize.symbolize_headers(normalized_headers) : normalized_headers

      expect(symbolized_headers).to eq(headers)
    end
  end
end