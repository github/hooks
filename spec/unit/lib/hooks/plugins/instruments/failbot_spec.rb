# frozen_string_literal: true

describe Hooks::Plugins::Instruments::Failbot do
  let(:failbot) { described_class.new }

  it "inherits from FailbotBase" do
    expect(described_class).to be < Hooks::Plugins::Instruments::FailbotBase
  end

  describe "#report" do
    it "does nothing by default" do
      expect { failbot.report("error", {}) }.not_to raise_error
    end
  end

  describe "#critical" do
    it "does nothing by default" do
      expect { failbot.critical("critical error", {}) }.not_to raise_error
    end
  end

  describe "#warning" do
    it "does nothing by default" do
      expect { failbot.warning("warning message", {}) }.not_to raise_error
    end
  end

  describe "#capture" do
    it "yields block and does nothing on success" do
      result = failbot.capture({ context: "test" }) do
        "block_result"
      end

      expect(result).to eq("block_result")
    end

    it "captures but does nothing with exceptions" do
      error = StandardError.new("test error")

      expect do
        failbot.capture({ context: "test" }) do
          raise error
        end
      end.to raise_error(error)
    end
  end
end
