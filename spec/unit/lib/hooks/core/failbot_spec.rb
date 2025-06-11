# frozen_string_literal: true

describe Hooks::Core::Failbot do
  let(:failbot) { described_class.new }

  describe "#report" do
    it "can be called with string message" do
      expect { failbot.report("Test error message") }.not_to raise_error
    end

    it "can be called with exception" do
      exception = StandardError.new("Test exception")
      expect { failbot.report(exception) }.not_to raise_error
    end

    it "accepts context parameter" do
      expect { failbot.report("Error", { handler: "TestHandler" }) }.not_to raise_error
    end

    it "can be overridden in subclasses" do
      custom_failbot_class = Class.new(described_class) do
        def initialize
          @reported_errors = []
        end

        def report(error_or_message, context = {})
          @reported_errors << { error: error_or_message, context: }
        end

        attr_reader :reported_errors
      end

      custom_failbot = custom_failbot_class.new
      custom_failbot.report("Test error", { test: true })

      expect(custom_failbot.reported_errors).to eq([
        { error: "Test error", context: { test: true } }
      ])
    end
  end

  describe "#critical" do
    it "can be called with string message" do
      expect { failbot.critical("Critical error") }.not_to raise_error
    end

    it "can be called with exception" do
      exception = StandardError.new("Critical exception")
      expect { failbot.critical(exception) }.not_to raise_error
    end

    it "accepts context parameter" do
      expect { failbot.critical("Critical", { handler: "TestHandler" }) }.not_to raise_error
    end
  end

  describe "#warning" do
    it "can be called with message" do
      expect { failbot.warning("Warning message") }.not_to raise_error
    end

    it "accepts context parameter" do
      expect { failbot.warning("Warning", { handler: "TestHandler" }) }.not_to raise_error
    end
  end

  describe "#capture" do
    it "returns block result when no exception" do
      result = failbot.capture { "success" }
      expect(result).to eq("success")
    end

    it "reports and re-raises exceptions" do
      capturing_failbot_class = Class.new(described_class) do
        def initialize
          @captured_errors = []
        end

        def report(error_or_message, context = {})
          @captured_errors << { error: error_or_message, context: }
        end

        attr_reader :captured_errors
      end

      capturing_failbot = capturing_failbot_class.new
      test_error = StandardError.new("Test error")

      expect {
        capturing_failbot.capture({ test: true }) { raise test_error }
      }.to raise_error(test_error)

      expect(capturing_failbot.captured_errors).to eq([
        { error: test_error, context: { test: true } }
      ])
    end
  end
end
