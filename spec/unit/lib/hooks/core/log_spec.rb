# frozen_string_literal: true

describe Hooks::Log do
  after do
    # Clean up any mock loggers to avoid interference with other tests
    described_class.instance = nil
  end

  describe ".instance" do
    it "has an accessor for the logger instance" do
      expect(described_class).to respond_to(:instance)
      expect(described_class).to respond_to(:instance=)
    end

    it "can set and get the logger instance" do
      mock_logger = instance_double(Logger)
      described_class.instance = mock_logger
      expect(described_class.instance).to eq(mock_logger)
    end

    it "starts with nil instance" do
      described_class.instance = nil
      expect(described_class.instance).to be_nil
    end

    it "can handle different logger types" do
      # Test with different logger implementations
      standard_logger = Logger.new(StringIO.new)
      described_class.instance = standard_logger
      expect(described_class.instance).to eq(standard_logger)

      # Test with mock logger
      mock_logger = double("MockLogger")
      described_class.instance = mock_logger
      expect(described_class.instance).to eq(mock_logger)
    end
  end

  describe "module structure" do
    it "is a module within Hooks namespace" do
      expect(described_class).to be_a(Module)
      expect(described_class.name).to eq("Hooks::Log")
    end

    it "has a singleton class with instance accessor" do
      singleton = described_class.singleton_class
      expect(singleton.method_defined?(:instance)).to be true
      expect(singleton.method_defined?(:instance=)).to be true
    end
  end
end