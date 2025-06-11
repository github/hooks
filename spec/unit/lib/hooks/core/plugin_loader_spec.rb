# frozen_string_literal: true

require_relative "../../../spec_helper"

describe Hooks::Core::PluginLoader do
  let(:temp_dir) { "/tmp/hooks_plugin_test" }
  let(:auth_plugin_dir) { File.join(temp_dir, "auth") }
  let(:handler_plugin_dir) { File.join(temp_dir, "handlers") }

  before do
    FileUtils.mkdir_p(auth_plugin_dir)
    FileUtils.mkdir_p(handler_plugin_dir)
    
    # Clear plugin registries
    allow(described_class).to receive(:log_loaded_plugins)
  end

  after do
    FileUtils.rm_rf(temp_dir)
  end

  describe ".load_all_plugins" do
    context "with default configuration" do
      it "loads built-in plugins" do
        config = { auth_plugin_dir: nil, handler_plugin_dir: nil }
        
        described_class.load_all_plugins(config)
        
        expect(described_class.auth_plugins).to include(
          "hmac" => Hooks::Plugins::Auth::HMAC,
          "shared_secret" => Hooks::Plugins::Auth::SharedSecret
        )
        
        expect(described_class.handler_plugins).to include(
          "DefaultHandler" => DefaultHandler
        )
      end
    end

    context "with custom plugin directories" do
      let(:custom_auth_content) do
        <<~RUBY
          module Hooks
            module Plugins
              module Auth
                class CustomAuth < Base
                  DEFAULT_CONFIG = { header: "X-Custom-Auth" }.freeze
                  
                  def self.valid?(payload:, headers:, config:)
                    # Simple validation for testing
                    headers.key?(config.dig(:auth, :header) || DEFAULT_CONFIG[:header])
                  end
                end
              end
            end
          end
        RUBY
      end

      let(:custom_handler_content) do
        <<~RUBY
          class CustomHandler < Hooks::Plugins::Handlers::Base
            def call(payload:, headers:, config:)
              { message: "custom handler executed", payload: payload }
            end
          end
        RUBY
      end

      before do
        File.write(File.join(auth_plugin_dir, "custom_auth.rb"), custom_auth_content)
        File.write(File.join(handler_plugin_dir, "custom_handler.rb"), custom_handler_content)
      end

      it "loads both built-in and custom plugins" do
        config = {
          auth_plugin_dir: auth_plugin_dir,
          handler_plugin_dir: handler_plugin_dir
        }
        
        described_class.load_all_plugins(config)
        
        # Built-in plugins should still be available
        expect(described_class.auth_plugins).to include(
          "hmac" => Hooks::Plugins::Auth::HMAC,
          "shared_secret" => Hooks::Plugins::Auth::SharedSecret
        )
        expect(described_class.handler_plugins).to include(
          "DefaultHandler" => DefaultHandler
        )
        
        # Custom plugins should also be available
        expect(described_class.auth_plugins).to include("custom_auth")
        expect(described_class.handler_plugins).to include("CustomHandler")
        
        # Verify custom auth plugin works
        custom_auth_class = described_class.auth_plugins["custom_auth"]
        expect(custom_auth_class).to be < Hooks::Plugins::Auth::Base
        expect(custom_auth_class.valid?(
          payload: "test",
          headers: { "X-Custom-Auth" => "token" },
          config: { auth: {} }
        )).to be true
        
        # Verify custom handler plugin works
        custom_handler_class = described_class.handler_plugins["CustomHandler"]
        expect(custom_handler_class).to be < Hooks::Plugins::Handlers::Base
        handler_instance = custom_handler_class.new
        result = handler_instance.call(payload: "test", headers: {}, config: {})
        expect(result).to include(message: "custom handler executed", payload: "test")
      end
    end

    context "with non-existent plugin directories" do
      it "handles missing directories gracefully" do
        config = {
          auth_plugin_dir: "/nonexistent/auth",
          handler_plugin_dir: "/nonexistent/handlers"
        }
        
        expect { described_class.load_all_plugins(config) }.not_to raise_error
        
        # Should still have built-in plugins
        expect(described_class.auth_plugins).to include(
          "hmac" => Hooks::Plugins::Auth::HMAC,
          "shared_secret" => Hooks::Plugins::Auth::SharedSecret
        )
        expect(described_class.handler_plugins).to include(
          "DefaultHandler" => DefaultHandler
        )
      end
    end
  end

  describe ".get_auth_plugin" do
    before do
      described_class.load_all_plugins({ auth_plugin_dir: nil, handler_plugin_dir: nil })
    end

    it "returns built-in auth plugins" do
      expect(described_class.get_auth_plugin("hmac")).to eq(Hooks::Plugins::Auth::HMAC)
      expect(described_class.get_auth_plugin("shared_secret")).to eq(Hooks::Plugins::Auth::SharedSecret)
    end

    it "raises error for non-existent plugin" do
      expect { described_class.get_auth_plugin("nonexistent") }.to raise_error(
        StandardError, /Auth plugin 'nonexistent' not found/
      )
    end
  end

  describe ".get_handler_plugin" do
    before do
      described_class.load_all_plugins({ auth_plugin_dir: nil, handler_plugin_dir: nil })
    end

    it "returns built-in handler plugins" do
      expect(described_class.get_handler_plugin("DefaultHandler")).to eq(DefaultHandler)
    end

    it "raises error for non-existent plugin" do
      expect { described_class.get_handler_plugin("NonExistentHandler") }.to raise_error(
        StandardError, /Handler plugin 'NonExistentHandler' not found/
      )
    end
  end
end