# frozen_string_literal: true

describe Hooks::Plugins::Instruments::FailbotBase do
  let(:failbot) { described_class.new }

  describe "#log" do
    it "provides access to the global logger" do
      allow(Hooks::Log).to receive(:instance).and_return(double("Logger"))
      expect(failbot.log).to eq(Hooks::Log.instance)
    end
  end
end
