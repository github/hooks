# frozen_string_literal: true

describe DefaultHandler do
  let(:handler) { described_class.new }
  let(:payload) { { message: "test payload", data: { key: "value" } } }
  let(:headers) { { "Content-Type" => "application/json", "User-Agent" => "TestAgent" } }
  let(:config) { { endpoint: "test", auth: { type: "hmac" } } }

  before do
    # Provide a null logger to avoid nil errors while allowing logging to work
    Hooks::Log.instance = Logger.new(StringIO.new)
  end

  describe "#call" do
    context "with valid payload and headers" do
      it "returns successful response hash" do
        response = handler.call(payload: payload, headers: headers, config: config)

        expect(response).to be_a(Hash)
        expect(response[:message]).to eq("webhook processed successfully")
        expect(response[:handler]).to eq("DefaultHandler")
        expect(response[:timestamp]).to be_a(String)
        expect(response[:timestamp]).to match(/\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z/)
      end

      it "uses the mocked time from spec helper" do
        response = handler.call(payload: payload, headers: headers, config: config)
        expect(response[:timestamp]).to eq(TIME_MOCK)
      end
    end

    context "with nil payload" do
      it "returns successful response without errors" do
        response = handler.call(payload: nil, headers: headers, config: config)

        expect(response).to be_a(Hash)
        expect(response[:message]).to eq("webhook processed successfully")
        expect(response[:handler]).to eq("DefaultHandler")
        expect(response[:timestamp]).to eq(TIME_MOCK)
      end
    end

    context "with empty payload" do
      it "handles empty payload gracefully" do
        response = handler.call(payload: {}, headers: headers, config: config)

        expect(response).to be_a(Hash)
        expect(response[:message]).to eq("webhook processed successfully")
        expect(response[:handler]).to eq("DefaultHandler")
        expect(response[:timestamp]).to eq(TIME_MOCK)
      end
    end

    context "with string payload" do
      let(:string_payload) { "plain text payload" }

      it "handles string payload successfully" do
        response = handler.call(payload: string_payload, headers: headers, config: config)

        expect(response[:message]).to eq("webhook processed successfully")
        expect(response[:handler]).to eq("DefaultHandler")
        expect(response[:timestamp]).to eq(TIME_MOCK)
      end
    end

    context "with different config values" do
      let(:custom_config) { { endpoint: "custom", custom_field: "test" } }

      it "accepts any config without affecting response" do
        response = handler.call(payload: payload, headers: headers, config: custom_config)

        expect(response[:message]).to eq("webhook processed successfully")
        expect(response[:handler]).to eq("DefaultHandler")
        expect(response[:timestamp]).to eq(TIME_MOCK)
      end
    end

    context "with different headers" do
      let(:custom_headers) { { "X-GitHub-Event" => "push", "X-GitHub-Delivery" => "12345" } }

      it "accepts any headers without affecting response" do
        response = handler.call(payload: payload, headers: custom_headers, config: config)

        expect(response[:message]).to eq("webhook processed successfully")
        expect(response[:handler]).to eq("DefaultHandler")
        expect(response[:timestamp]).to eq(TIME_MOCK)
      end
    end
  end

  describe "inheritance" do
    it "inherits from Hooks::Handlers::Base" do
      expect(described_class.superclass).to eq(Hooks::Handlers::Base)
    end
  end
end