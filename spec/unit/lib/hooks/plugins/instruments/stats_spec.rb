# frozen_string_literal: true

describe Hooks::Plugins::Instruments::Stats do
  let(:stats) { described_class.new }

  it "inherits from StatsBase" do
    expect(described_class).to be < Hooks::Plugins::Instruments::StatsBase
    expect(stats).to be_a(Hooks::Plugins::Instruments::StatsBase)
  end
end
