# frozen_string_literal: true

describe Hooks::VERSION do
  it "has a version number" do
    expect(Hooks::VERSION).not_to be nil
    expect(Hooks::VERSION).to match(/^\d+\.\d+\.\d+$/)
  end
end
