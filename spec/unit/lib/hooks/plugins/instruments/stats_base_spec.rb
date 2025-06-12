# frozen_string_literal: true

describe Hooks::Plugins::Instruments::StatsBase do
  let(:stats) { described_class.new }

  describe "#log" do
    it "provides access to the global logger" do
      allow(Hooks::Log).to receive(:instance).and_return(double("Logger"))
      expect(stats.log).to eq(Hooks::Log.instance)
    end
  end
end
