# frozen_string_literal: true

describe Hooks::Plugins::Handlers::Error do
  describe "#initialize" do
    it "creates an error with default status 500" do
      error = described_class.new("test error")
      expect(error.body).to eq("test error")
      expect(error.status).to eq(500)
      expect(error.message).to eq("Handler error: 500 - test error")
    end

    it "creates an error with custom status" do
      error = described_class.new({ error: "validation_failed" }, 400)
      expect(error.body).to eq({ error: "validation_failed" })
      expect(error.status).to eq(400)
      expect(error.message).to eq("Handler error: 400 - {error: \"validation_failed\"}")
    end

    it "converts status to integer" do
      error = described_class.new("test", "404")
      expect(error.status).to eq(404)
    end
  end

  describe "inheritance" do
    it "inherits from StandardError" do
      expect(described_class.ancestors).to include(StandardError)
    end
  end
end
