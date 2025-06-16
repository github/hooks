# frozen_string_literal: true

require_relative "../../../spec_helper"

describe "Handler Loading Tests" do
  let(:test_class) do
    Class.new do
      include Hooks::App::Helpers

      def error!(message, code)
        raise StandardError, "#{message} (#{code})"
      end

      def headers
        {}
      end

      def env
        {}
      end
    end
  end

  let(:instance) { test_class.new }

  before do
    # Clear plugin registries before each test
    Hooks::Core::PluginLoader.clear_plugins
  end

  after do
    # Clear plugin registries after each test
    Hooks::Core::PluginLoader.clear_plugins
  end

  describe "#load_handler" do
    context "when handler is not loaded at boot time" do
      it "returns error indicating handler not found" do
        expect do
          instance.load_handler("NonexistentHandler")
        end.to raise_error(StandardError, /Handler plugin.*not found/)
      end

      it "returns error for any handler class name when no plugins loaded" do
        handler_names = ["MyHandler", "GitHubHandler", "Team1Handler"]

        handler_names.each do |name|
          expect do
            instance.load_handler(name)
          end.to raise_error(StandardError, /Handler plugin.*not found/)
        end
      end
    end

    context "when built-in handler is loaded at boot time" do
      before do
        # Load built-in plugins (includes DefaultHandler)
        Hooks::Core::PluginLoader.load_all_plugins({})
      end

      it "successfully loads DefaultHandler" do
        handler = instance.load_handler("DefaultHandler")
        expect(handler).to be_an_instance_of(DefaultHandler)
      end
    end
  end
end
