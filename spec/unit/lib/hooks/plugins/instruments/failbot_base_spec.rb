# frozen_string_literal: true

describe Hooks::Plugins::Instruments::FailbotBase do
  let(:failbot) { described_class.new }

  describe "#log" do
    it "provides access to the global logger" do
      allow(Hooks::Log).to receive(:instance).and_return(double("Logger"))
      expect(failbot.log).to eq(Hooks::Log.instance)
    end
  end

  describe "#report" do
    it "raises NotImplementedError" do
      expect { failbot.report("error", {}) }.to raise_error(NotImplementedError, "Failbot instrument must implement #report method")
    end
  end

  describe "#critical" do
    it "raises NotImplementedError" do
      expect { failbot.critical("critical error", {}) }.to raise_error(NotImplementedError, "Failbot instrument must implement #critical method")
    end
  end

  describe "#warning" do
    it "raises NotImplementedError" do
      expect { failbot.warning("warning message", {}) }.to raise_error(NotImplementedError, "Failbot instrument must implement #warning method")
    end
  end

  describe "#capture" do
    it "yields block and captures exceptions" do
      allow(failbot).to receive(:report)

      result = failbot.capture({ context: "test" }) do
        "block_result"
      end

      expect(result).to eq("block_result")
      expect(failbot).not_to have_received(:report)
    end

    it "captures and re-raises exceptions" do
      error = StandardError.new("test error")
      allow(failbot).to receive(:report)

      expect do
        failbot.capture({ context: "test" }) do
          raise error
        end
      end.to raise_error(error)

      expect(failbot).to have_received(:report).with(error, { context: "test" })
    end
  end
end