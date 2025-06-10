# frozen_string_literal: true

describe Hooks::Core::SignalHandler do
  let(:logger) { double("Logger", info: nil) }

  describe "#initialize" do
    it "initializes with logger and default graceful timeout" do
      handler = described_class.new(logger)

      expect(handler.shutdown_requested?).to be false
    end

    it "initializes with custom graceful timeout" do
      handler = described_class.new(logger, graceful_timeout: 60)

      expect(handler.shutdown_requested?).to be false
    end

    it "stores the logger instance" do
      handler = described_class.new(logger)

      expect(handler.instance_variable_get(:@logger)).to be(logger)
    end

    it "stores the graceful timeout" do
      handler = described_class.new(logger, graceful_timeout: 45)

      expect(handler.instance_variable_get(:@graceful_timeout)).to eq(45)
    end

    it "sets default graceful timeout to 30 seconds" do
      handler = described_class.new(logger)

      expect(handler.instance_variable_get(:@graceful_timeout)).to eq(30)
    end

    it "initializes shutdown_requested to false" do
      handler = described_class.new(logger)

      expect(handler.instance_variable_get(:@shutdown_requested)).to be false
    end
  end

  describe "#shutdown_requested?" do
    let(:handler) { described_class.new(logger) }

    it "returns false initially" do
      expect(handler.shutdown_requested?).to be false
    end

    it "returns true after shutdown is requested" do
      handler.request_shutdown

      expect(handler.shutdown_requested?).to be true
    end

    it "remains true once set" do
      handler.request_shutdown

      expect(handler.shutdown_requested?).to be true
      expect(handler.shutdown_requested?).to be true
    end
  end

  describe "#request_shutdown" do
    let(:handler) { described_class.new(logger) }

    it "sets shutdown_requested to true" do
      expect(handler.shutdown_requested?).to be false

      handler.request_shutdown

      expect(handler.shutdown_requested?).to be true
    end

    it "logs the shutdown request" do
      expect(logger).to receive(:info).with("Shutdown requested")

      handler.request_shutdown
    end

    it "can be called multiple times without error" do
      expect(logger).to receive(:info).twice

      handler.request_shutdown
      handler.request_shutdown

      expect(handler.shutdown_requested?).to be true
    end

    it "logs each time it's called" do
      expect(logger).to receive(:info).with("Shutdown requested").twice

      handler.request_shutdown
      handler.request_shutdown
    end
  end

  describe "#setup_signal_traps" do
    let(:handler) { described_class.new(logger) }

    it "is a private method" do
      expect(described_class.private_instance_methods).to include(:setup_signal_traps)
    end

    # Note: The setup_signal_traps method is currently disabled in the implementation
    # as noted in the comment "NOTE: Disabled for now to let Puma handle signals properly"
    # The signal trapping functionality is commented out but the method structure remains
    it "exists but is currently disabled" do
      expect(handler.respond_to?(:setup_signal_traps, true)).to be true
    end
  end

  describe "thread safety" do
    let(:handler) { described_class.new(logger) }

    it "handles concurrent access to shutdown_requested?" do
      allow(logger).to receive(:info)

      threads = 10.times.map do
        Thread.new do
          100.times do
            handler.shutdown_requested?
            handler.request_shutdown if rand < 0.1 # Randomly request shutdown
          end
        end
      end

      threads.each(&:join)

      # Should not raise any errors and should end up with shutdown requested
      expect(handler.shutdown_requested?).to be true
    end
  end

  describe "edge cases" do
    context "with nil logger" do
      it "raises an error when trying to log" do
        handler = described_class.new(nil)

        expect {
          handler.request_shutdown
        }.to raise_error(NoMethodError)
      end
    end

    context "with zero graceful timeout" do
      it "accepts zero timeout without error" do
        expect {
          described_class.new(logger, graceful_timeout: 0)
        }.not_to raise_error
      end
    end

    context "with negative graceful timeout" do
      it "accepts negative timeout without error" do
        expect {
          described_class.new(logger, graceful_timeout: -10)
        }.not_to raise_error
      end
    end
  end
end
