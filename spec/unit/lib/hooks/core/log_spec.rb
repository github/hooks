# frozen_string_literal: true

describe Hooks::Log do
  describe ".instance" do
    it "can be set and retrieved" do
      logger = instance_double(Logger)
      described_class.instance = logger

      expect(described_class.instance).to eq(logger)
    end

    it "can be set to nil" do
      described_class.instance = nil

      expect(described_class.instance).to be_nil
    end

    it "maintains the same instance when set" do
      logger = instance_double(Logger)
      described_class.instance = logger

      expect(described_class.instance).to be(logger)
    end

    it "can be overridden" do
      first_logger = instance_double(Logger)
      second_logger = instance_double(Logger)

      described_class.instance = first_logger
      expect(described_class.instance).to eq(first_logger)

      described_class.instance = second_logger
      expect(described_class.instance).to eq(second_logger)
    end
  end
end
