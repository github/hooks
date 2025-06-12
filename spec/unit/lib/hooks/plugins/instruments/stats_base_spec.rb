# frozen_string_literal: true

describe Hooks::Plugins::Instruments::StatsBase do
  let(:stats) { described_class.new }

  describe "#log" do
    it "provides access to the global logger" do
      allow(Hooks::Log).to receive(:instance).and_return(double("Logger"))
      expect(stats.log).to eq(Hooks::Log.instance)
    end
  end

  describe "#record" do
    it "raises NotImplementedError" do
      expect { stats.record("metric", 1.0, {}) }.to raise_error(NotImplementedError, "Stats instrument must implement #record method")
    end
  end

  describe "#increment" do
    it "raises NotImplementedError" do
      expect { stats.increment("counter", {}) }.to raise_error(NotImplementedError, "Stats instrument must implement #increment method")
    end
  end

  describe "#timing" do
    it "raises NotImplementedError" do
      expect { stats.timing("timer", 0.5, {}) }.to raise_error(NotImplementedError, "Stats instrument must implement #timing method")
    end
  end

  describe "#measure" do
    it "measures execution time and calls timing" do
      allow(stats).to receive(:timing)
      result = stats.measure("test_metric", { tag: "value" }) do
        "block_result"
      end

      expect(result).to eq("block_result")
      expect(stats).to have_received(:timing).with("test_metric", kind_of(Numeric), { tag: "value" })
    end
  end
end