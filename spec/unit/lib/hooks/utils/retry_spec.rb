# frozen_string_literal: true

require_relative "../../../spec_helper"

# Import the tested class
require_relative "../../../../../lib/hooks/utils/retry"

describe Retry do
  let(:logger) { instance_double("Logger") }

  before do
    # Reset any previous configuration
    Retryable.configuration.contexts.clear
  end

  describe ".setup!" do
    context "with valid parameters" do
      it "sets up retry configuration with default values" do
        allow(ENV).to receive(:fetch).and_call_original
        allow(ENV).to receive(:fetch).with("DEFAULT_RETRY_SLEEP", "1").and_return("1")
        allow(ENV).to receive(:fetch).with("DEFAULT_RETRY_TRIES", "10").and_return("10")
        allow(ENV).to receive(:fetch).with("RETRY_LOG_RETRIES", "true").and_return("true")

        Retry.setup!(log: logger)

        expect(Retryable.configuration.contexts[:default]).to include(
          sleep: 1,
          tries: 10
        )
      end

      it "accepts custom retry configuration within bounds" do
        allow(ENV).to receive(:fetch).and_call_original
        allow(ENV).to receive(:fetch).with("DEFAULT_RETRY_SLEEP", "1").and_return("5")
        allow(ENV).to receive(:fetch).with("DEFAULT_RETRY_TRIES", "10").and_return("3")
        allow(ENV).to receive(:fetch).with("RETRY_LOG_RETRIES", "true").and_return("false")

        Retry.setup!(log: logger)

        expect(Retryable.configuration.contexts[:default]).to include(
          sleep: 5,
          tries: 3
        )
      end
    end

    context "with invalid parameters" do
      it "raises ArgumentError when no logger is provided" do
        expect do
          Retry.setup!(log: nil)
        end.to raise_error(ArgumentError, "a logger must be provided")
      end

      it "raises ArgumentError when retry sleep is negative" do
        allow(ENV).to receive(:fetch).and_call_original
        allow(ENV).to receive(:fetch).with("DEFAULT_RETRY_SLEEP", "1").and_return("-1")
        allow(ENV).to receive(:fetch).with("DEFAULT_RETRY_TRIES", "10").and_return("10")

        expect do
          Retry.setup!(log: logger)
        end.to raise_error(ArgumentError, /DEFAULT_RETRY_SLEEP must be between 0 and 300/)
      end

      it "raises ArgumentError when retry sleep exceeds maximum" do
        allow(ENV).to receive(:fetch).and_call_original
        allow(ENV).to receive(:fetch).with("DEFAULT_RETRY_SLEEP", "1").and_return("301")
        allow(ENV).to receive(:fetch).with("DEFAULT_RETRY_TRIES", "10").and_return("10")

        expect do
          Retry.setup!(log: logger)
        end.to raise_error(ArgumentError, /DEFAULT_RETRY_SLEEP must be between 0 and 300/)
      end

      it "raises ArgumentError when retry tries is zero" do
        allow(ENV).to receive(:fetch).and_call_original
        allow(ENV).to receive(:fetch).with("DEFAULT_RETRY_SLEEP", "1").and_return("1")
        allow(ENV).to receive(:fetch).with("DEFAULT_RETRY_TRIES", "10").and_return("0")

        expect do
          Retry.setup!(log: logger)
        end.to raise_error(ArgumentError, /DEFAULT_RETRY_TRIES must be between 1 and 50/)
      end

      it "raises ArgumentError when retry tries exceeds maximum" do
        allow(ENV).to receive(:fetch).and_call_original
        allow(ENV).to receive(:fetch).with("DEFAULT_RETRY_SLEEP", "1").and_return("1")
        allow(ENV).to receive(:fetch).with("DEFAULT_RETRY_TRIES", "10").and_return("51")

        expect do
          Retry.setup!(log: logger)
        end.to raise_error(ArgumentError, /DEFAULT_RETRY_TRIES must be between 1 and 50/)
      end
    end

    context "with boundary values" do
      it "accepts minimum valid values" do
        allow(ENV).to receive(:fetch).and_call_original
        allow(ENV).to receive(:fetch).with("DEFAULT_RETRY_SLEEP", "1").and_return("0")
        allow(ENV).to receive(:fetch).with("DEFAULT_RETRY_TRIES", "10").and_return("1")
        allow(ENV).to receive(:fetch).with("RETRY_LOG_RETRIES", "true").and_return("true")

        expect do
          Retry.setup!(log: logger)
        end.not_to raise_error

        expect(Retryable.configuration.contexts[:default]).to include(
          sleep: 0,
          tries: 1
        )
      end

      it "accepts maximum valid values" do
        allow(ENV).to receive(:fetch).and_call_original
        allow(ENV).to receive(:fetch).with("DEFAULT_RETRY_SLEEP", "1").and_return("300")
        allow(ENV).to receive(:fetch).with("DEFAULT_RETRY_TRIES", "10").and_return("50")
        allow(ENV).to receive(:fetch).with("RETRY_LOG_RETRIES", "true").and_return("true")

        expect do
          Retry.setup!(log: logger)
        end.not_to raise_error

        expect(Retryable.configuration.contexts[:default]).to include(
          sleep: 300,
          tries: 50
        )
      end
    end
  end
end
