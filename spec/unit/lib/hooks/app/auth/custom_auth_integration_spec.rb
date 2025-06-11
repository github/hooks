# frozen_string_literal: true

require_relative "../../../../spec_helper"

describe "Custom Auth Plugin Integration" do
  let(:custom_auth_plugin_dir) { "/tmp/test_auth_plugins" }
  let(:plugin_file_content) do
    <<~RUBY
      module Hooks
        module Plugins
          module Auth
            class SomeCoolAuthPlugin < Base
              def self.valid?(payload:, headers:, config:)
                # Mock implementation: check for specific header
                secret = fetch_secret(config)
                bearer_token = headers["authorization"]
                bearer_token == "Bearer \#{secret}"
              end
            end
          end
        end
      end
    RUBY
  end

  let(:global_config) do
    {
      auth_plugin_dir: custom_auth_plugin_dir,
      handler_plugin_dir: "./spec/acceptance/handlers"
    }
  end

  let(:endpoint_config) do
    {
      path: "/example",
      handler: "DefaultHandler",
      auth: {
        type: "some_cool_auth_plugin",
        secret_env_key: "SUPER_COOL_SECRET",
        header: "Authorization"
      }
    }
  end

  before do
    FileUtils.mkdir_p(custom_auth_plugin_dir)
    File.write(File.join(custom_auth_plugin_dir, "some_cool_auth_plugin.rb"), plugin_file_content)
    ENV["SUPER_COOL_SECRET"] = "test-secret"
  end

  after do
    FileUtils.rm_rf(custom_auth_plugin_dir) if Dir.exist?(custom_auth_plugin_dir)
    ENV.delete("SUPER_COOL_SECRET")
  end

  it "successfully validates using a custom auth plugin" do
    # Create a test API class using the same pattern as the real API
    test_api_class = Class.new do
      include Hooks::App::Helpers
      include Hooks::App::Auth

      def error!(message, code)
        raise StandardError, "#{message} (#{code})"
      end
    end

    instance = test_api_class.new
    payload = '{"test": "data"}'
    headers = { "authorization" => "Bearer test-secret" }

    # This should not raise any error
    expect do
      instance.validate_auth!(payload, headers, endpoint_config, global_config)
    end.not_to raise_error
  end

  it "rejects requests with invalid credentials using custom auth plugin" do
    test_api_class = Class.new do
      include Hooks::App::Helpers
      include Hooks::App::Auth

      def error!(message, code)
        raise StandardError, "#{message} (#{code})"
      end
    end

    instance = test_api_class.new
    payload = '{"test": "data"}'
    headers = { "authorization" => "Bearer wrong-secret" }

    # This should raise authentication failed error
    expect do
      instance.validate_auth!(payload, headers, endpoint_config, global_config)
    end.to raise_error(StandardError, /authentication failed/)
  end

  it "works with the new configuration format" do
    # Test the new auth_plugin_dir configuration
    config = Hooks::Core::ConfigLoader.load(config_path: {
      auth_plugin_dir: "./custom/auth/plugins",
      handler_plugin_dir: "./custom/handlers"
    })

    expect(config[:auth_plugin_dir]).to eq("./custom/auth/plugins")
    expect(config[:handler_plugin_dir]).to eq("./custom/handlers")
  end

  it "uses handler_plugin_dir configuration" do
    # Test that handler_plugin_dir configuration works
    config = Hooks::Core::ConfigLoader.load(config_path: {
      handler_plugin_dir: "./custom/handlers"
    })

    expect(config[:handler_plugin_dir]).to eq("./custom/handlers")
  end
end
