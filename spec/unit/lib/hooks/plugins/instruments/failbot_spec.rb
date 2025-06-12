# frozen_string_literal: true

describe Hooks::Plugins::Instruments::Failbot do
  let(:failbot) { described_class.new }

  it "inherits from FailbotBase" do
    expect(described_class).to be < Hooks::Plugins::Instruments::FailbotBase
    expect(failbot).to be_a(Hooks::Plugins::Instruments::FailbotBase)
  end
end
