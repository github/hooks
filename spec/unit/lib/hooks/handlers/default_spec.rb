# frozen_string_literal: true

describe DefaultHandler do
  let(:log) { instance_double(Logger).as_null_object }
  let(:payload) { { "action" => "opened", "number" => 1 } }
  let(:headers) { { "X-GitHub-Event" => "pull_request" } }
  let(:config) { { environment: "test" } }
  let(:handler) { described_class.new }

  before do
    allow(handler).to receive(:log).and_return(log)
  end

  describe "#call" do
    context "with valid parameters" do
      let(:result) { handler.call(payload:, headers:, config:) }

      it "logs that the default handler was invoked" do
        result

        expect(log).to have_received(:info).with("🔔 Default handler invoked for webhook 🔔")
      end

      it "logs payload debug information when payload is present" do
        result

        expect(log).to have_received(:debug).with("received payload: #{payload.inspect}")
      end

      it "returns a success response hash" do
        expect(result).to be_a(Hash)
        expect(result).to include(
          message: "webhook processed successfully",
          handler: "DefaultHandler",
          timestamp: TIME_MOCK
        )
      end

      it "includes timestamp in ISO8601 format" do
        expect(result[:timestamp]).to eq(TIME_MOCK)
      end
    end

    context "with nil payload" do
      let(:payload) { nil }
      let(:result) { handler.call(payload:, headers:, config:) }

      it "does not log payload debug information" do
        result

        expect(log).not_to have_received(:debug)
      end

      it "still returns a success response" do
        expect(result).to include(
          message: "webhook processed successfully",
          handler: "DefaultHandler"
        )
      end
    end

    context "with empty payload" do
      let(:payload) { {} }
      let(:result) { handler.call(payload:, headers:, config:) }

      it "logs the empty payload" do
        result

        expect(log).to have_received(:debug).with("received payload: #{payload.inspect}")
      end
    end

    context "with complex payload" do
      let(:payload) do
        {
          "action" => "opened",
          "pull_request" => {
            "id" => 123,
            "title" => "Test PR",
            "body" => "This is a test"
          }
        }
      end
      let(:result) { handler.call(payload:, headers:, config:) }

      it "logs the complex payload structure" do
        result

        expect(log).to have_received(:debug).with("received payload: #{payload.inspect}")
      end
    end
  end

  describe "inheritance" do
    it "inherits from Hooks::Handlers::Base" do
      expect(described_class.superclass).to eq(Hooks::Handlers::Base)
    end
  end
end