# frozen_string_literal: true

describe Hooks::Core::GlobalComponents do
  describe ".stats" do
    it "returns a Stats instance by default" do
      expect(described_class.stats).to be_a(Hooks::Core::Stats)
    end

    it "can be set to a custom stats instance" do
      custom_stats = double("CustomStats")
      original_stats = described_class.stats

      described_class.stats = custom_stats
      expect(described_class.stats).to eq(custom_stats)

      # Restore original for other tests
      described_class.stats = original_stats
    end
  end

  describe ".failbot" do
    it "returns a Failbot instance by default" do
      expect(described_class.failbot).to be_a(Hooks::Core::Failbot)
    end

    it "can be set to a custom failbot instance" do
      custom_failbot = double("CustomFailbot")
      original_failbot = described_class.failbot

      described_class.failbot = custom_failbot
      expect(described_class.failbot).to eq(custom_failbot)

      # Restore original for other tests
      described_class.failbot = original_failbot
    end
  end

  describe ".reset" do
    it "resets both components to default instances" do
      # Set custom instances
      custom_stats = double("CustomStats")
      custom_failbot = double("CustomFailbot")
      described_class.stats = custom_stats
      described_class.failbot = custom_failbot

      # Reset
      described_class.reset

      # Verify they are back to default instances
      expect(described_class.stats).to be_a(Hooks::Core::Stats)
      expect(described_class.failbot).to be_a(Hooks::Core::Failbot)
    end
  end
end
