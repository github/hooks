# frozen_string_literal: true

describe Hooks::Utils::Normalize do
  describe ".header" do
    context "when input is a single string" do
      it "normalizes header name to lowercase and trims whitespace" do
        expect(described_class.header("  Content-Type  ")).to eq("content-type")
        expect(described_class.header("X-GitHub-Event")).to eq("x-github-event")
        expect(described_class.header("AUTHORIZATION")).to eq("authorization")
      end

      it "handles empty and nil string inputs" do
        expect(described_class.header("")).to eq("")
        expect(described_class.header("   ")).to eq("")
        expect(described_class.header(nil)).to eq(nil)
      end

      it "raises ArgumentError for non-string inputs" do
        expect { described_class.header(123) }.to raise_error(ArgumentError, "Expected a String for header normalization")
        expect { described_class.header({}) }.to raise_error(ArgumentError, "Expected a String for header normalization")
        expect { described_class.header([]) }.to raise_error(ArgumentError, "Expected a String for header normalization")
      end
    end
  end

  describe ".headers" do

    context "when input is a hash of headers" do
      it "normalizes header keys to lowercase and trims values" do
        headers = {
          "Content-Type" => "  application/json  ",
          "X-GitHub-Event" => "push",
          "AUTHORIZATION" => " Bearer token123 "
        }

        normalized = described_class.headers(headers)

        expect(normalized).to eq({
          "content-type" => "application/json",
          "x-github-event" => "push",
          "authorization" => "Bearer token123"
        })
      end

      it "handles nil and empty values" do
        headers = {
          "valid-header" => "value",
          "empty-header" => "",
          "nil-header" => nil,
          nil => "should-be-skipped"
        }

        normalized = described_class.headers(headers)

        expect(normalized).to eq({
          "valid-header" => "value"
        })
      end

      it "handles array values by taking the first non-empty element" do
        headers = {
          "multi-value" => ["first", "second", "third"],
          "empty-array" => [],
          "nil-in-array" => [nil, "", "valid"],
          "all-empty-array" => ["", "  ", nil]
        }

        normalized = described_class.headers(headers)

        expect(normalized).to eq({
          "multi-value" => "first",
          "nil-in-array" => "valid"
        })
      end

      it "handles non-string values by converting to string" do
        headers = {
          "numeric-header" => 123,
          "boolean-header" => true,
          "symbol-header" => :symbol_value
        }

        normalized = described_class.headers(headers)

        expect(normalized).to eq({
          "numeric-header" => "123",
          "boolean-header" => "true",
          "symbol-header" => "symbol_value"
        })
      end

      it "skips headers with empty keys after normalization" do
        headers = {
          "  " => "should-be-skipped",
          "" => "also-skipped",
          "valid-key" => "kept"
        }

        normalized = described_class.headers(headers)

        expect(normalized).to eq({
          "valid-key" => "kept"
        })
      end

      it "handles nil input" do
        expect(described_class.headers(nil)).to eq(nil)
      end

      it "handles empty hash input" do
        expect(described_class.headers({})).to eq({})
      end

      it "handles non-enumerable input" do
        expect(described_class.headers(123)).to eq({})
        expect(described_class.headers(true)).to eq({})
      end
    end
  end

  describe ".symbolize_headers" do
    context "when input is a hash of headers" do
      it "converts header keys to symbols and replaces hyphens with underscores" do
        headers = {
          "content-type" => "application/json",
          "x-github-event" => "push",
          "user-agent" => "test-agent",
          "authorization" => "Bearer token123"
        }

        symbolized = described_class.symbolize_headers(headers)

        expect(symbolized).to eq({
          content_type: "application/json",
          x_github_event: "push",
          user_agent: "test-agent",
          authorization: "Bearer token123"
        })
      end

      it "handles mixed case and already symbolized keys" do
        headers = {
          "Content-Type" => "application/json",
          "X-GitHub-Event" => "push",
          :already_symbol => "value"
        }

        symbolized = described_class.symbolize_headers(headers)

        expect(symbolized).to eq({
          Content_Type: "application/json",
          X_GitHub_Event: "push",
          already_symbol: "value"
        })
      end

      it "handles nil keys by skipping them" do
        headers = {
          "valid-header" => "value",
          nil => "should-be-skipped"
        }

        symbolized = described_class.symbolize_headers(headers)

        expect(symbolized).to eq({
          valid_header: "value"
        })
      end

      it "handles nil input" do
        expect(described_class.symbolize_headers(nil)).to eq(nil)
      end

      it "handles empty hash input" do
        expect(described_class.symbolize_headers({})).to eq({})
      end

      it "handles non-enumerable input" do
        expect(described_class.symbolize_headers(123)).to eq({})
        expect(described_class.symbolize_headers(true)).to eq({})
      end

      it "preserves header values unchanged" do
        headers = {
          "x-custom-header" => ["array", "values"],
          "numeric-header" => 123,
          "boolean-header" => true
        }

        symbolized = described_class.symbolize_headers(headers)

        expect(symbolized).to eq({
          x_custom_header: ["array", "values"],
          numeric_header: 123,
          boolean_header: true
        })
      end
    end
  end
end
