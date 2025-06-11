# frozen_string_literal: true

require_relative "../../../../spec_helper"

describe Hooks::App::Auth do
  let(:log) { instance_double(Logger).as_null_object }
  let(:test_class) do
    Class.new do
      include Hooks::App::Auth
      include Hooks::App::Helpers

      def error!(message, code)
        raise StandardError, "#{message} (#{code})"
      end
    end
  end

  let(:instance) { test_class.new }
  let(:payload) { '{"test": "data"}' }
  let(:headers) { { "Content-Type" => "application/json" } }

  before(:each) do
    Hooks::Log.instance = log
  end

  describe "#validate_auth! with custom auth plugins" do
    let(:custom_auth_plugin_dir) { "/tmp/custom_auth_plugins_test" }
    let(:global_config) { { auth_plugin_dir: custom_auth_plugin_dir } }

    before do
      # Create temporary directory for custom auth plugins
      FileUtils.mkdir_p(custom_auth_plugin_dir)
    end

    after do
      # Clean up
      FileUtils.rm_rf(custom_auth_plugin_dir) if Dir.exist?(custom_auth_plugin_dir)
    end

    context "when custom auth plugin is configured but directory not set" do
      it "falls back to POC error message" do
        endpoint_config = { auth: { type: "some_cool_auth_plugin" } }
        empty_global_config = {}

        expect do
          instance.validate_auth!(payload, headers, endpoint_config, empty_global_config)
        end.to raise_error(StandardError, /unsupported auth type/)
      end
    end

    context "when custom auth plugin exists and is valid" do
      let(:plugin_file_content) do
        <<~RUBY
          module Hooks
            module Plugins
              module Auth
                class SomeCoolAuthPlugin < Base
                  def self.valid?(payload:, headers:, config:)
                    # Mock validation - always return true
                    true
                  end
                end
              end
            end
          end
        RUBY
      end

      before do
        File.write(File.join(custom_auth_plugin_dir, "some_cool_auth_plugin.rb"), plugin_file_content)
      end

      it "loads and uses the custom auth plugin successfully" do
        endpoint_config = { auth: { type: "some_cool_auth_plugin" } }

        expect do
          instance.validate_auth!(payload, headers, endpoint_config, global_config)
        end.not_to raise_error
      end
    end

    context "when custom auth plugin fails validation" do
      let(:plugin_file_content) do
        <<~RUBY
          module Hooks
            module Plugins
              module Auth
                class FailingAuthPlugin < Base
                  def self.valid?(payload:, headers:, config:)
                    # Mock validation - always return false
                    false
                  end
                end
              end
            end
          end
        RUBY
      end

      before do
        File.write(File.join(custom_auth_plugin_dir, "failing_auth_plugin.rb"), plugin_file_content)
      end

      it "returns authentication failed error" do
        endpoint_config = { auth: { type: "failing_auth_plugin" } }

        expect do
          instance.validate_auth!(payload, headers, endpoint_config, global_config)
        end.to raise_error(StandardError, /authentication failed/)
      end
    end

    context "when custom auth plugin file does not exist" do
      it "returns custom plugin loading error" do
        endpoint_config = { auth: { type: "nonexistent_plugin" } }

        expect do
          instance.validate_auth!(payload, headers, endpoint_config, global_config)
        end.to raise_error(StandardError, /Auth plugin NonexistentPlugin not found/)
      end
    end

    context "when custom auth plugin has security issues" do
      context "with invalid class name" do
        it "converts lowercase plugin name and fails to find file" do
          endpoint_config = { auth: { type: "lowercase_plugin" } }

          expect do
            instance.validate_auth!(payload, headers, endpoint_config, global_config)
          end.to raise_error(StandardError, /Auth plugin LowercasePlugin not found/)
        end

        it "rejects plugin with special characters" do
          endpoint_config = { auth: { type: "plugin$bad" } }

          expect do
            instance.validate_auth!(payload, headers, endpoint_config, global_config)
          end.to raise_error(StandardError, /invalid auth plugin type/)
        end
      end

      context "with plugin that doesn't inherit from Base" do
        let(:bad_plugin_file_content) do
          <<~RUBY
            module Hooks
              module Plugins
                module Auth
                  class BadPlugin
                    def self.valid?(payload:, headers:, config:)
                      true
                    end
                  end
                end
              end
            end
          RUBY
        end

        before do
          File.write(File.join(custom_auth_plugin_dir, "bad_plugin.rb"), bad_plugin_file_content)
        end

        it "rejects plugin that doesn't inherit from Base" do
          endpoint_config = { auth: { type: "bad_plugin" } }

          expect do
            instance.validate_auth!(payload, headers, endpoint_config, global_config)
          end.to raise_error(StandardError, /auth plugin class must inherit from/)
        end
      end
    end

    context "with complex plugin names" do
      let(:plugin_file_content) do
        <<~RUBY
          module Hooks
            module Plugins
              module Auth
                class GitHubOAuth2Plugin < Base
                  def self.valid?(payload:, headers:, config:)
                    true
                  end
                end
              end
            end
          end
        RUBY
      end

      before do
        File.write(File.join(custom_auth_plugin_dir, "git_hub_o_auth2_plugin.rb"), plugin_file_content)
      end

      it "handles complex CamelCase names correctly" do
        endpoint_config = { auth: { type: "git_hub_o_auth2_plugin" } }

        expect do
          instance.validate_auth!(payload, headers, endpoint_config, global_config)
        end.not_to raise_error
      end
    end
  end
end
