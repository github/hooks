# frozen_string_literal: true

require_relative "spec_helper"

describe Hooks do
  describe ".build" do
    context "with default parameters" do
      it "creates a builder and builds the application" do
        allow(Hooks::Core::Builder).to receive(:new).and_call_original
        allow_any_instance_of(Hooks::Core::Builder).to receive(:build).and_return("mock_app")

        result = Hooks.build

        expect(Hooks::Core::Builder).to have_received(:new).with(config: nil, log: nil)
        expect(result).to eq("mock_app")
      end
    end

    context "with custom config" do
      it "passes config to builder" do
        config_hash = { log_level: "debug" }
        allow(Hooks::Core::Builder).to receive(:new).and_call_original
        allow_any_instance_of(Hooks::Core::Builder).to receive(:build).and_return("mock_app")

        result = Hooks.build(config: config_hash)

        expect(Hooks::Core::Builder).to have_received(:new).with(config: config_hash, log: nil)
        expect(result).to eq("mock_app")
      end
    end

    context "with custom logger" do
      it "passes logger to builder" do
        custom_logger = double("Logger")
        allow(Hooks::Core::Builder).to receive(:new).and_call_original
        allow_any_instance_of(Hooks::Core::Builder).to receive(:build).and_return("mock_app")

        result = Hooks.build(log: custom_logger)

        expect(Hooks::Core::Builder).to have_received(:new).with(config: nil, log: custom_logger)
        expect(result).to eq("mock_app")
      end
    end

    context "with both config and logger" do
      it "passes both to builder" do
        config_hash = { environment: "test" }
        custom_logger = double("Logger")
        allow(Hooks::Core::Builder).to receive(:new).and_call_original
        allow_any_instance_of(Hooks::Core::Builder).to receive(:build).and_return("mock_app")

        result = Hooks.build(config: config_hash, log: custom_logger)

        expect(Hooks::Core::Builder).to have_received(:new).with(config: config_hash, log: custom_logger)
        expect(result).to eq("mock_app")
      end
    end
  end
end
