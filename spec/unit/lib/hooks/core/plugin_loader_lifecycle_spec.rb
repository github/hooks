# frozen_string_literal: true

describe Hooks::Core::PluginLoader do
  # Reset plugin state between tests
  around do |example|
    original_auth = described_class.auth_plugins.dup
    original_handler = described_class.handler_plugins.dup
    original_lifecycle = described_class.lifecycle_plugins.dup

    example.run

    # Restore original state
    described_class.instance_variable_set(:@auth_plugins, original_auth)
    described_class.instance_variable_set(:@handler_plugins, original_handler)
    described_class.instance_variable_set(:@lifecycle_plugins, original_lifecycle)
  end

  describe ".lifecycle_plugins" do
    it "returns an array" do
      expect(described_class.lifecycle_plugins).to be_an(Array)
    end

    it "starts empty" do
      described_class.clear_plugins
      expect(described_class.lifecycle_plugins).to be_empty
    end
  end

  describe ".load_all_plugins" do
    it "loads lifecycle plugins from directory" do
      # Create a temporary lifecycle plugin file
      temp_dir = Dir.mktmpdir("lifecycle_plugins")
      plugin_file = File.join(temp_dir, "test_lifecycle.rb")

      File.write(plugin_file, <<~RUBY)
        class TestLifecycle < Hooks::Plugins::Lifecycle
          def on_request(env)
            # Test implementation
          end
        end
      RUBY

      config = { lifecycle_plugin_dir: temp_dir }

      expect {
        described_class.load_all_plugins(config)
      }.not_to raise_error

      expect(described_class.lifecycle_plugins).not_to be_empty
      expect(described_class.lifecycle_plugins.first).to be_a(TestLifecycle)

      # Cleanup
      FileUtils.rm_rf(temp_dir)
    end

    it "handles missing lifecycle plugin directory gracefully" do
      config = { lifecycle_plugin_dir: "/nonexistent/directory" }

      expect {
        described_class.load_all_plugins(config)
      }.not_to raise_error

      # Should not affect existing plugins
      expect(described_class.auth_plugins).not_to be_empty
      expect(described_class.handler_plugins).not_to be_empty
    end

    it "handles nil lifecycle plugin directory gracefully" do
      config = { lifecycle_plugin_dir: nil }

      expect {
        described_class.load_all_plugins(config)
      }.not_to raise_error
    end
  end

  describe ".clear_plugins" do
    it "clears lifecycle plugins" do
      # Simulate having some lifecycle plugins
      described_class.instance_variable_set(:@lifecycle_plugins, [double("Plugin")])

      described_class.clear_plugins

      expect(described_class.lifecycle_plugins).to be_empty
    end
  end

  describe ".log_loaded_plugins" do
    it "includes lifecycle plugin count in logs" do
      # Mock a logger that captures messages
      logger_double = double("Logger")
      allow(Hooks::Log).to receive(:instance).and_return(logger_double)
      allow(logger_double).to receive(:class).and_return(double(name: "TestLogger"))

      expect(logger_double).to receive(:info).with(/Loaded \d+ auth plugins/)
      expect(logger_double).to receive(:info).with(/Loaded \d+ handler plugins/)
      expect(logger_double).to receive(:info).with(/Loaded \d+ lifecycle plugins/)

      described_class.send(:log_loaded_plugins)
    end
  end

  describe "lifecycle plugin validation" do
    describe ".valid_lifecycle_class_name?" do
      it "accepts valid class names" do
        expect(described_class.send(:valid_lifecycle_class_name?, "TestLifecycle")).to be true
        expect(described_class.send(:valid_lifecycle_class_name?, "LoggingLifecycle")).to be true
        expect(described_class.send(:valid_lifecycle_class_name?, "Custom123Lifecycle")).to be true
      end

      it "rejects invalid class names" do
        expect(described_class.send(:valid_lifecycle_class_name?, "")).to be false
        expect(described_class.send(:valid_lifecycle_class_name?, "lowercase")).to be false
        expect(described_class.send(:valid_lifecycle_class_name?, "123Invalid")).to be false
        expect(described_class.send(:valid_lifecycle_class_name?, nil)).to be false
        expect(described_class.send(:valid_lifecycle_class_name?, "Class-WithDash")).to be false
      end

      it "rejects dangerous class names" do
        # We can't mock the frozen constant, so we'll test with a name we know is in the list
        expect(described_class.send(:valid_lifecycle_class_name?, "Object")).to be false
        expect(described_class.send(:valid_lifecycle_class_name?, "Class")).to be false
        expect(described_class.send(:valid_lifecycle_class_name?, "Module")).to be false
      end
    end
  end

  describe "lifecycle plugin loading" do
    it "validates plugin file paths for security" do
      temp_dir = Dir.mktmpdir("lifecycle_plugins")
      outside_file = File.join(Dir.tmpdir, "evil_plugin.rb")

      File.write(outside_file, "class EvilPlugin; end")

      expect {
        described_class.send(:load_custom_lifecycle_plugin, outside_file, temp_dir)
      }.to raise_error(SecurityError, /outside of lifecycle plugin directory/)

      # Cleanup
      FileUtils.rm_rf(temp_dir)
      File.delete(outside_file) if File.exist?(outside_file)
    end

    it "validates plugin inheritance" do
      temp_dir = Dir.mktmpdir("lifecycle_plugins")
      plugin_file = File.join(temp_dir, "invalid_lifecycle.rb")

      File.write(plugin_file, <<~RUBY)
        class InvalidLifecycle
          # Does not inherit from Hooks::Plugins::Lifecycle
        end
      RUBY

      expect {
        described_class.send(:load_custom_lifecycle_plugin, plugin_file, temp_dir)
      }.to raise_error(StandardError, /must inherit from Hooks::Plugins::Lifecycle/)

      # Cleanup
      FileUtils.rm_rf(temp_dir)
    end
  end
end
