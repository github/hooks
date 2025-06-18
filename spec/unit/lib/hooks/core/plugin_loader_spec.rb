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

    # Clear plugins to avoid test interference
    described_class.clear_plugins
    # Reload default plugins
    described_class.load_all_plugins({
      auth_plugin_dir: nil,
      handler_plugin_dir: nil
    })
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
          #{'        '}
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
            def call(payload:, headers:, env:, config:)
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
        result = handler_instance.call(payload: "test", headers: {}, env: {}, config: {})
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
      expect(described_class.get_handler_plugin("default_handler")).to eq(DefaultHandler)
    end

    it "raises error for non-existent plugin" do
      expect { described_class.get_handler_plugin("non_existent_handler") }.to raise_error(
        StandardError, /Handler plugin 'non_existent_handler' not found/
      )
    end
  end

  describe "failure scenarios" do
    describe "auth plugin loading failures" do
      it "raises error when auth plugin file fails to load" do
        temp_auth_dir = File.join(temp_dir, "auth_failures")
        FileUtils.mkdir_p(temp_auth_dir)

        # Create a malformed Ruby file
        malformed_file = File.join(temp_auth_dir, "broken_auth.rb")
        File.write(malformed_file, "class BrokenAuth\n  # Missing end statement")

        expect {
          described_class.load_all_plugins({ auth_plugin_dir: temp_auth_dir })
        }.to raise_error(StandardError, /Failed to load auth plugin from.*broken_auth\.rb/)
      end

      it "raises error for auth plugin path traversal attempt" do
        temp_auth_dir = File.join(temp_dir, "auth_secure")
        FileUtils.mkdir_p(temp_auth_dir)

        # Create a plugin file outside the auth directory
        outside_file = File.join(temp_dir, "outside_auth.rb")
        File.write(outside_file, "# Outside file")

        expect {
          described_class.send(:load_custom_auth_plugin, outside_file, temp_auth_dir)
        }.to raise_error(SecurityError, /Auth plugin path outside of auth plugin directory/)
      end

      it "raises error for invalid auth plugin class name" do
        temp_auth_dir = File.join(temp_dir, "auth_invalid")
        FileUtils.mkdir_p(temp_auth_dir)

        # Create plugin with invalid class name
        invalid_file = File.join(temp_auth_dir, "file.rb")
        File.write(invalid_file, "# File with dangerous class name")

        expect {
          described_class.send(:load_custom_auth_plugin, invalid_file, temp_auth_dir)
        }.to raise_error(StandardError, /Invalid auth plugin class name: File/)
      end

      it "raises error when auth plugin doesn't inherit from correct base class" do
        temp_auth_dir = File.join(temp_dir, "auth_inheritance")
        FileUtils.mkdir_p(temp_auth_dir)

        # Create plugin with wrong inheritance
        wrong_file = File.join(temp_auth_dir, "wrong_auth.rb")
        File.write(wrong_file, <<~RUBY)
          module Hooks
            module Plugins
              module Auth
                class WrongAuth
                  def self.valid?(payload:, headers:, config:)
                    true
                  end
                end
              end
            end
          end
        RUBY

        expect {
          described_class.send(:load_custom_auth_plugin, wrong_file, temp_auth_dir)
        }.to raise_error(StandardError, /Auth plugin class must inherit from Hooks::Plugins::Auth::Base/)
      end
    end

    it "raises error when auth plugin class is not found after loading" do
      temp_auth_dir = File.join(temp_dir, "auth_missing_class")
      FileUtils.mkdir_p(temp_auth_dir)

      # Create plugin file that doesn't define the expected class
      missing_file = File.join(temp_auth_dir, "missing_auth.rb")
      File.write(missing_file, <<~RUBY)
        # This file doesn't define MissingAuth class
        module Hooks
          module Plugins
            module Auth
              # Nothing here
            end
          end
        end
      RUBY

      expect {
        described_class.send(:load_custom_auth_plugin, missing_file, temp_auth_dir)
      }.to raise_error(StandardError, /Auth plugin class not found in Hooks::Plugins::Auth namespace: MissingAuth/)
    end

    describe "handler plugin loading failures" do
      it "raises error when handler plugin file fails to load" do
        temp_handler_dir = File.join(temp_dir, "handler_failures")
        FileUtils.mkdir_p(temp_handler_dir)

        # Create a malformed Ruby file
        malformed_file = File.join(temp_handler_dir, "broken_handler.rb")
        File.write(malformed_file, "class BrokenHandler\n  # Missing end statement")

        expect {
          described_class.load_all_plugins({ handler_plugin_dir: temp_handler_dir })
        }.to raise_error(StandardError, /Failed to load handler plugin from.*broken_handler\.rb/)
      end

      it "raises error for handler plugin path traversal attempt" do
        temp_handler_dir = File.join(temp_dir, "handler_secure")
        FileUtils.mkdir_p(temp_handler_dir)

        # Create a plugin file outside the handler directory
        outside_file = File.join(temp_dir, "outside_handler.rb")
        File.write(outside_file, "# Outside file")

        expect {
          described_class.send(:load_custom_handler_plugin, outside_file, temp_handler_dir)
        }.to raise_error(SecurityError, /Handler plugin path outside of handler plugin directory/)
      end

      it "raises error for invalid handler plugin class name" do
        temp_handler_dir = File.join(temp_dir, "handler_invalid")
        FileUtils.mkdir_p(temp_handler_dir)

        # Create plugin with invalid class name
        invalid_file = File.join(temp_handler_dir, "file.rb")
        File.write(invalid_file, "# File with dangerous class name")

        expect {
          described_class.send(:load_custom_handler_plugin, invalid_file, temp_handler_dir)
        }.to raise_error(StandardError, /Invalid handler class name: File/)
      end

      it "raises error when handler plugin doesn't inherit from correct base class" do
        temp_handler_dir = File.join(temp_dir, "handler_inheritance")
        FileUtils.mkdir_p(temp_handler_dir)

        # Create plugin with wrong inheritance
        wrong_file = File.join(temp_handler_dir, "wrong_handler.rb")
        File.write(wrong_file, <<~RUBY)
          class WrongHandler
            def call(payload:, headers:, env:, config:)
              { message: "wrong handler" }
            end
          end
        RUBY

        expect {
          described_class.send(:load_custom_handler_plugin, wrong_file, temp_handler_dir)
        }.to raise_error(StandardError, /Handler class must inherit from Hooks::Plugins::Handlers::Base/)
      end

      it "raises error when handler plugin class is not found after loading" do
        temp_handler_dir = File.join(temp_dir, "handler_missing_class")
        FileUtils.mkdir_p(temp_handler_dir)

        # Create plugin file that doesn't define the expected class
        missing_file = File.join(temp_handler_dir, "missing_handler.rb")
        File.write(missing_file, <<~RUBY)
          # This file doesn't define MissingHandler class
          class SomeOtherClass
          end
        RUBY

        expect {
          described_class.send(:load_custom_handler_plugin, missing_file, temp_handler_dir)
        }.to raise_error(StandardError, /Handler class not found: MissingHandler/)
      end
    end

    describe "lifecycle plugin loading failures" do
      it "raises error when lifecycle plugin file fails to load" do
        temp_lifecycle_dir = File.join(temp_dir, "lifecycle_failures")
        FileUtils.mkdir_p(temp_lifecycle_dir)

        # Create a malformed Ruby file
        malformed_file = File.join(temp_lifecycle_dir, "broken_lifecycle.rb")
        File.write(malformed_file, "class BrokenLifecycle\n  # Missing end statement")

        expect {
          described_class.load_all_plugins({ lifecycle_plugin_dir: temp_lifecycle_dir })
        }.to raise_error(StandardError, /Failed to load lifecycle plugin from.*broken_lifecycle\.rb/)
      end

      it "raises error for lifecycle plugin path traversal attempt" do
        temp_lifecycle_dir = File.join(temp_dir, "lifecycle_secure")
        FileUtils.mkdir_p(temp_lifecycle_dir)

        # Create a plugin file outside the lifecycle directory
        outside_file = File.join(temp_dir, "outside_lifecycle.rb")
        File.write(outside_file, "# Outside file")

        expect {
          described_class.send(:load_custom_lifecycle_plugin, outside_file, temp_lifecycle_dir)
        }.to raise_error(SecurityError, /Lifecycle plugin path outside of lifecycle plugin directory/)
      end

      it "raises error for invalid lifecycle plugin class name" do
        temp_lifecycle_dir = File.join(temp_dir, "lifecycle_invalid")
        FileUtils.mkdir_p(temp_lifecycle_dir)

        # Create plugin with invalid class name
        invalid_file = File.join(temp_lifecycle_dir, "file.rb")
        File.write(invalid_file, "# File with dangerous class name")

        expect {
          described_class.send(:load_custom_lifecycle_plugin, invalid_file, temp_lifecycle_dir)
        }.to raise_error(StandardError, /Invalid lifecycle plugin class name: File/)
      end

      it "raises error when lifecycle plugin doesn't inherit from correct base class" do
        temp_lifecycle_dir = File.join(temp_dir, "lifecycle_inheritance")
        FileUtils.mkdir_p(temp_lifecycle_dir)

        # Create plugin with wrong inheritance
        wrong_file = File.join(temp_lifecycle_dir, "wrong_lifecycle.rb")
        File.write(wrong_file, <<~RUBY)
          class WrongLifecycle
            def on_request(env)
              # Wrong base class
            end
          end
        RUBY

        expect {
          described_class.send(:load_custom_lifecycle_plugin, wrong_file, temp_lifecycle_dir)
        }.to raise_error(StandardError, /Lifecycle plugin class must inherit from Hooks::Plugins::Lifecycle/)
      end

      it "raises error when lifecycle plugin class is not found after loading" do
        temp_lifecycle_dir = File.join(temp_dir, "lifecycle_missing_class")
        FileUtils.mkdir_p(temp_lifecycle_dir)

        # Create plugin file that doesn't define the expected class
        missing_file = File.join(temp_lifecycle_dir, "missing_lifecycle.rb")
        File.write(missing_file, <<~RUBY)
          # This file doesn't define MissingLifecycle class
          class SomeOtherClass
          end
        RUBY

        expect {
          described_class.send(:load_custom_lifecycle_plugin, missing_file, temp_lifecycle_dir)
        }.to raise_error(StandardError, /Lifecycle plugin class not found: MissingLifecycle/)
      end
    end

    describe "instrument plugin loading failures" do
      it "raises error when instrument plugin file fails to load" do
        temp_instrument_dir = File.join(temp_dir, "instrument_failures")
        FileUtils.mkdir_p(temp_instrument_dir)

        # Create a malformed Ruby file
        malformed_file = File.join(temp_instrument_dir, "broken_instrument.rb")
        File.write(malformed_file, "class BrokenInstrument\n  # Missing end statement")

        expect {
          described_class.load_all_plugins({ instruments_plugin_dir: temp_instrument_dir })
        }.to raise_error(StandardError, /Failed to load instrument plugin from.*broken_instrument\.rb/)
      end

      it "raises error for instrument plugin path traversal attempt" do
        temp_instrument_dir = File.join(temp_dir, "instrument_secure")
        FileUtils.mkdir_p(temp_instrument_dir)

        # Create a plugin file outside the instrument directory
        outside_file = File.join(temp_dir, "outside_instrument.rb")
        File.write(outside_file, "# Outside file")

        expect {
          described_class.send(:load_custom_instrument_plugin, outside_file, temp_instrument_dir)
        }.to raise_error(SecurityError, /Instrument plugin path outside of instruments plugin directory/)
      end

      it "raises error for invalid instrument plugin class name" do
        temp_instrument_dir = File.join(temp_dir, "instrument_invalid")
        FileUtils.mkdir_p(temp_instrument_dir)

        # Create plugin with invalid class name
        invalid_file = File.join(temp_instrument_dir, "file.rb")
        File.write(invalid_file, "# File with dangerous class name")

        expect {
          described_class.send(:load_custom_instrument_plugin, invalid_file, temp_instrument_dir)
        }.to raise_error(StandardError, /Invalid instrument plugin class name: File/)
      end

      it "raises error when instrument plugin doesn't inherit from correct base class" do
        temp_instrument_dir = File.join(temp_dir, "instrument_inheritance")
        FileUtils.mkdir_p(temp_instrument_dir)

        # Create plugin with wrong inheritance
        wrong_file = File.join(temp_instrument_dir, "wrong_instrument.rb")
        File.write(wrong_file, <<~RUBY)
          class WrongInstrument
            def record(metric_name, value, tags = {})
              # Wrong base class
            end
          end
        RUBY

        expect {
          described_class.send(:load_custom_instrument_plugin, wrong_file, temp_instrument_dir)
        }.to raise_error(StandardError, /Instrument plugin class must inherit from StatsBase or FailbotBase/)
      end

      it "raises error when instrument plugin class is not found after loading" do
        temp_instrument_dir = File.join(temp_dir, "instrument_missing_class")
        FileUtils.mkdir_p(temp_instrument_dir)

        # Create plugin file that doesn't define the expected classAdd commentMore actions
        missing_file = File.join(temp_instrument_dir, "missing_instrument.rb")
        File.write(missing_file, <<~RUBY)
          # This file doesn't define MissingInstrument class
          class SomeOtherClass
          end
        RUBY

        expect {
          described_class.send(:load_custom_instrument_plugin, missing_file, temp_instrument_dir)
        }.to raise_error(StandardError, /Instrument plugin class not found: MissingInstrument/)
      end
    end
  end
end
