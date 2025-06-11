# frozen_string_literal: true

describe Hooks::Core::ConfigLoader do
  describe ".load" do
    context "with no config_path provided" do
      it "returns default configuration" do
        config = described_class.load

        expect(config).to include(
          handler_plugin_dir: "./plugins/handlers",
          auth_plugin_dir: "./plugins/auth",
          log_level: "info",
          request_limit: 1_048_576,
          request_timeout: 30,
          root_path: "/webhooks",
          health_path: "/health",
          version_path: "/version",
          environment: "production",
          production: true,
          endpoints_dir: "./config/endpoints",
          use_catchall_route: false,
          symbolize_payload: true,
          normalize_headers: true
        )
      end
    end

    context "with hash config_path" do
      it "merges hash with defaults" do
        custom_config = { log_level: "debug", environment: "test" }

        config = described_class.load(config_path: custom_config)

        expect(config[:log_level]).to eq("debug")
        expect(config[:environment]).to eq("test")
        expect(config[:production]).to be false # should be false when environment is test
        expect(config[:handler_plugin_dir]).to eq("./plugins/handlers") # defaults should remain
      end
    end

    context "with file config_path" do
      let(:temp_dir) { "/tmp/hooks_test" }

      before do
        FileUtils.mkdir_p(temp_dir)
      end

      after do
        FileUtils.rm_rf(temp_dir)
      end

      context "when file exists and is YAML" do
        let(:config_file) { File.join(temp_dir, "config.yml") }
        let(:yaml_content) do
          {
            "log_level" => "debug",
            "environment" => "development",
            "request_timeout" => 60
          }
        end

        before do
          File.write(config_file, yaml_content.to_yaml)
        end

        it "loads and merges YAML config" do
          config = described_class.load(config_path: config_file)

          expect(config[:log_level]).to eq("debug")
          expect(config[:environment]).to eq("development")
          expect(config[:request_timeout]).to eq(60)
          expect(config[:production]).to be false
          expect(config[:handler_plugin_dir]).to eq("./plugins/handlers") # defaults should remain
        end
      end

      context "when file exists and is JSON" do
        let(:config_file) { File.join(temp_dir, "config.json") }
        let(:json_content) do
          {
            "log_level" => "warn",
            "environment" => "staging",
            "endpoints_dir" => "./custom/endpoints"
          }
        end

        before do
          File.write(config_file, json_content.to_json)
        end

        it "loads and merges JSON config" do
          config = described_class.load(config_path: config_file)

          expect(config[:log_level]).to eq("warn")
          expect(config[:environment]).to eq("staging")
          expect(config[:endpoints_dir]).to eq("./custom/endpoints")
          expect(config[:production]).to be false
        end
      end

      context "when file does not exist" do
        let(:config_file) { File.join(temp_dir, "nonexistent.yml") }

        it "returns default configuration" do
          config = described_class.load(config_path: config_file)

          expect(config[:log_level]).to eq("info")
          expect(config[:environment]).to eq("production")
          expect(config[:production]).to be true
        end
      end

      context "when file has invalid content" do
        let(:config_file) { File.join(temp_dir, "invalid.yml") }

        before do
          File.write(config_file, "invalid: yaml: content: [")
        end

        it "returns default configuration" do
          config = described_class.load(config_path: config_file)

          expect(config[:log_level]).to eq("info")
          expect(config[:environment]).to eq("production")
        end
      end

      context "when file has unsupported extension" do
        let(:config_file) { File.join(temp_dir, "config.txt") }

        before do
          File.write(config_file, "log_level: debug")
        end

        it "returns default configuration" do
          config = described_class.load(config_path: config_file)

          expect(config[:log_level]).to eq("info")
          expect(config[:environment]).to eq("production")
        end
      end
    end

    context "with environment variables" do
      around do |example|
        original_env = ENV.to_h
        example.run
        ENV.replace(original_env)
      end

      it "overrides config with environment variables" do
        ENV["HOOKS_LOG_LEVEL"] = "error"
        ENV["HOOKS_ENVIRONMENT"] = "development"
        ENV["HOOKS_REQUEST_LIMIT"] = "2097152"
        ENV["HOOKS_REQUEST_TIMEOUT"] = "45"

        config = described_class.load

        expect(config[:log_level]).to eq("error")
        expect(config[:environment]).to eq("development")
        expect(config[:request_limit]).to eq(2_097_152)
        expect(config[:request_timeout]).to eq(45)
        expect(config[:production]).to be false
      end

      it "handles partial environment variable overrides" do
        ENV["HOOKS_LOG_LEVEL"] = "warn"

        config = described_class.load

        expect(config[:log_level]).to eq("warn")
        expect(config[:environment]).to eq("production") # should remain default
        expect(config[:production]).to be true
      end

      it "processes empty environment variables (empty strings are truthy)" do
        ENV["HOOKS_LOG_LEVEL"] = ""

        config = described_class.load

        expect(config[:log_level]).to eq("") # empty string is processed
      end
    end

    context "with auth plugin directory configuration" do
      it "includes auth_plugin_dir in default configuration" do
        config = described_class.load

        expect(config).to include(auth_plugin_dir: "./plugins/auth")
      end

      it "loads auth_plugin_dir from hash config" do
        custom_config = { auth_plugin_dir: "./custom/auth/plugins" }

        config = described_class.load(config_path: custom_config)

        expect(config[:auth_plugin_dir]).to eq("./custom/auth/plugins")
      end

      it "loads auth_plugin_dir from environment variable" do
        ENV["HOOKS_AUTH_PLUGIN_DIR"] = "/opt/auth/plugins"

        config = described_class.load

        expect(config[:auth_plugin_dir]).to eq("/opt/auth/plugins")
      ensure
        ENV.delete("HOOKS_AUTH_PLUGIN_DIR")
      end
    end

    context "with production environment detection" do
      it "sets production to true when environment is production" do
        config = described_class.load(config_path: { environment: "production" })

        expect(config[:production]).to be true
      end

      it "sets production to false when environment is not production" do
        ["development", "test", "staging", "custom"].each do |env|
          config = described_class.load(config_path: { environment: env })

          expect(config[:production]).to be false
        end
      end
    end
  end

  describe ".load_endpoints" do
    let(:temp_dir) { "/tmp/hooks_endpoints_test" }

    before do
      FileUtils.mkdir_p(temp_dir)
    end

    after do
      FileUtils.rm_rf(temp_dir)
    end

    context "when endpoints_dir is nil" do
      it "returns empty array" do
        endpoints = described_class.load_endpoints(nil)

        expect(endpoints).to eq([])
      end
    end

    context "when endpoints_dir does not exist" do
      it "returns empty array" do
        endpoints = described_class.load_endpoints("/nonexistent/dir")

        expect(endpoints).to eq([])
      end
    end

    context "when endpoints_dir exists with YAML files" do
      let(:endpoint1_file) { File.join(temp_dir, "endpoint1.yml") }
      let(:endpoint2_file) { File.join(temp_dir, "endpoint2.yaml") }
      let(:endpoint1_config) do
        {
          "path" => "/webhook/test1",
          "handler" => "TestHandler1",
          "method" => "POST"
        }
      end
      let(:endpoint2_config) do
        {
          "path" => "/webhook/test2",
          "handler" => "TestHandler2",
          "method" => "PUT"
        }
      end

      before do
        File.write(endpoint1_file, endpoint1_config.to_yaml)
        File.write(endpoint2_file, endpoint2_config.to_yaml)
      end

      it "loads all YAML endpoint configurations" do
        endpoints = described_class.load_endpoints(temp_dir)

        expect(endpoints).to have_attributes(size: 2)
        expect(endpoints).to include(
          path: "/webhook/test1",
          handler: "TestHandler1",
          method: "POST"
        )
        expect(endpoints).to include(
          path: "/webhook/test2",
          handler: "TestHandler2",
          method: "PUT"
        )
      end
    end

    context "when endpoints_dir exists with JSON files" do
      let(:endpoint_file) { File.join(temp_dir, "endpoint.json") }
      let(:endpoint_config) do
        {
          "path" => "/webhook/json",
          "handler" => "JsonHandler",
          "method" => "POST"
        }
      end

      before do
        File.write(endpoint_file, endpoint_config.to_json)
      end

      it "loads JSON endpoint configuration" do
        endpoints = described_class.load_endpoints(temp_dir)

        expect(endpoints).to have_attributes(size: 1)
        expect(endpoints.first).to eq(
          path: "/webhook/json",
          handler: "JsonHandler",
          method: "POST"
        )
      end
    end

    context "when endpoints_dir has mixed valid and invalid files" do
      let(:valid_file) { File.join(temp_dir, "valid.yml") }
      let(:invalid_file) { File.join(temp_dir, "invalid.yml") }
      let(:txt_file) { File.join(temp_dir, "ignored.txt") }
      let(:valid_config) do
        {
          "path" => "/webhook/valid",
          "handler" => "ValidHandler"
        }
      end

      before do
        File.write(valid_file, valid_config.to_yaml)
        File.write(invalid_file, "invalid: yaml: [")
        File.write(txt_file, "This should be ignored")
      end

      it "loads only valid configurations and ignores invalid ones" do
        endpoints = described_class.load_endpoints(temp_dir)

        expect(endpoints).to have_attributes(size: 1)
        expect(endpoints.first).to eq(
          path: "/webhook/valid",
          handler: "ValidHandler"
        )
      end
    end
  end

  describe ".symbolize_keys" do
    it "converts string keys to symbols in a hash" do
      input = { "key1" => "value1", "key2" => "value2" }
      result = described_class.send(:symbolize_keys, input)

      expect(result).to eq({ key1: "value1", key2: "value2" })
    end

    it "recursively converts nested hash keys" do
      input = {
        "level1" => {
          "level2" => "value"
        }
      }
      result = described_class.send(:symbolize_keys, input)

      expect(result).to eq({
        level1: {
          level2: "value"
        }
      })
    end

    it "converts keys in arrays of hashes" do
      input = [
        { "key1" => "value1" },
        { "key2" => "value2" }
      ]
      result = described_class.send(:symbolize_keys, input)

      expect(result).to eq([
        { key1: "value1" },
        { key2: "value2" }
      ])
    end

    it "returns non-hash/array objects unchanged" do
      expect(described_class.send(:symbolize_keys, "string")).to eq("string")
      expect(described_class.send(:symbolize_keys, 123)).to eq(123)
      expect(described_class.send(:symbolize_keys, nil)).to be_nil
    end
  end
end
