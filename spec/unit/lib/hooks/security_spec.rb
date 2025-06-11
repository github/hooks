# frozen_string_literal: true

describe Hooks::Security do
  describe "DANGEROUS_CLASSES" do
    it "is frozen to prevent modification" do
      expect(described_class::DANGEROUS_CLASSES).to be_frozen
    end

    it "contains system-access classes" do
      expected_classes = %w[
        File Dir Kernel Object Class Module Proc Method
        IO Socket TCPSocket UDPSocket BasicSocket
        Process Thread Fiber Mutex ConditionVariable
        Marshal YAML JSON Pathname
      ]

      expect(described_class::DANGEROUS_CLASSES).to match_array(expected_classes)
    end

    it "contains file system classes" do
      expect(described_class::DANGEROUS_CLASSES).to include("File", "Dir", "Pathname")
    end

    it "contains network classes" do
      expect(described_class::DANGEROUS_CLASSES).to include("Socket", "TCPSocket", "UDPSocket", "BasicSocket")
    end

    it "contains process control classes" do
      expect(described_class::DANGEROUS_CLASSES).to include("Process", "Thread", "Fiber")
    end

    it "contains serialization classes" do
      expect(described_class::DANGEROUS_CLASSES).to include("Marshal", "YAML", "JSON")
    end

    it "contains core Ruby classes that provide system access" do
      expect(described_class::DANGEROUS_CLASSES).to include("Kernel", "Object", "Class", "Module")
    end

    it "prevents empty string attacks" do
      expect(described_class::DANGEROUS_CLASSES).not_to include("")
    end

    it "prevents nil attacks" do
      expect(described_class::DANGEROUS_CLASSES).not_to include(nil)
    end
  end
end