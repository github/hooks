# frozen_string_literal: true

describe Hooks::Plugins::Instruments::Stats do
  let(:stats) { described_class.new }

  it "inherits from StatsBase" do
    expect(described_class).to be < Hooks::Plugins::Instruments::StatsBase
  end

  describe "#record" do
    it "does nothing by default" do
      expect { stats.record("metric", 1.0, {}) }.not_to raise_error
    end
  end

  describe "#increment" do
    it "does nothing by default" do
      expect { stats.increment("counter", {}) }.not_to raise_error
    end
  end

  describe "#timing" do
    it "does nothing by default" do
      expect { stats.timing("timer", 0.5, {}) }.not_to raise_error
    end
  end

  describe "#measure" do
    it "still works for measuring execution time" do
      result = stats.measure("test_metric", { tag: "value" }) do
        "block_result"
      end

      expect(result).to eq("block_result")
    end
  end
end
