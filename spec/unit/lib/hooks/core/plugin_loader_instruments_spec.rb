# frozen_string_literal: true

describe Hooks::Core::PluginLoader do
  describe "instrument plugins" do
    let(:test_plugin_dir) { "/tmp/test_instrument_plugins" }

    before do
      # Clear plugins before each test
      described_class.clear_plugins

      # Create test plugin directory
      FileUtils.mkdir_p(test_plugin_dir)

      # Stub built-in plugins
      allow(described_class).to receive(:load_builtin_plugins)
    end

    after do
      # Clean up test directory
      FileUtils.rm_rf(test_plugin_dir) if Dir.exist?(test_plugin_dir)

      # Reset to defaults
      described_class.clear_plugins
      described_class.load_all_plugins({
        auth_plugin_dir: nil,
        handler_plugin_dir: nil,
        lifecycle_plugin_dir: nil,
        instruments_plugin_dir: nil
      })
    end

    describe ".load_custom_instrument_plugins" do
      it "loads custom stats instrument plugins" do
        # Create a custom stats plugin file
        custom_stats_content = <<~RUBY
        class CustomStats < Hooks::Plugins::Instruments::StatsBase
          def record(metric_name, value, tags = {})
            # Custom implementation
          end

          def increment(metric_name, tags = {})
            # Custom implementation
          end

          def timing(metric_name, duration, tags = {})
            # Custom implementation
          end
        end
      RUBY

        File.write(File.join(test_plugin_dir, "custom_stats.rb"), custom_stats_content)

        expect { described_class.send(:load_custom_instrument_plugins, test_plugin_dir) }.not_to raise_error

        # Verify the stats plugin was loaded
        expect(described_class.instrument_plugins[:stats]).to be_a(CustomStats)
      end

      it "loads custom failbot instrument plugins" do
        # Create a custom failbot plugin file
        custom_failbot_content = <<~RUBY
        class CustomFailbot < Hooks::Plugins::Instruments::FailbotBase
          def report(error_or_message, context = {})
            # Custom implementation
          end

          def critical(error_or_message, context = {})
            # Custom implementation
          end

          def warning(message, context = {})
            # Custom implementation
          end
        end
      RUBY

        File.write(File.join(test_plugin_dir, "custom_failbot.rb"), custom_failbot_content)

        expect { described_class.send(:load_custom_instrument_plugins, test_plugin_dir) }.not_to raise_error

        # Verify the failbot plugin was loaded
        expect(described_class.instrument_plugins[:failbot]).to be_a(CustomFailbot)
      end

      it "raises error for invalid inheritance" do
        # Create an invalid plugin file that doesn't inherit from base classes
        invalid_content = <<~RUBY
        class InvalidInstrument
          def some_method
            # This doesn't inherit from the right base class
          end
        end
      RUBY

        File.write(File.join(test_plugin_dir, "invalid_instrument.rb"), invalid_content)

        expect do
          described_class.send(:load_custom_instrument_plugins, test_plugin_dir)
        end.to raise_error(StandardError, /must inherit from StatsBase or FailbotBase/)
      end

      it "validates class names for security" do
        malicious_content = <<~RUBY
        class File < Hooks::Plugins::Instruments::StatsBase
          def record(metric_name, value, tags = {})
            # Malicious implementation
          end
        end
      RUBY

        File.write(File.join(test_plugin_dir, "file.rb"), malicious_content)

        expect do
          described_class.send(:load_custom_instrument_plugins, test_plugin_dir)
        end.to raise_error(StandardError, /Invalid instrument plugin class name/)
      end
    end

    describe ".get_instrument_plugin" do
      before do
        # Load default instruments
        described_class.send(:load_default_instruments)
      end

      it "returns the stats instrument" do
        stats = described_class.get_instrument_plugin(:stats)
        expect(stats).to be_a(Hooks::Plugins::Instruments::Stats)
      end

      it "returns the failbot instrument" do
        failbot = described_class.get_instrument_plugin(:failbot)
        expect(failbot).to be_a(Hooks::Plugins::Instruments::Failbot)
      end

      it "raises error for unknown instrument type" do
        expect do
          described_class.get_instrument_plugin(:unknown)
        end.to raise_error(StandardError, "Instrument plugin 'unknown' not found")
      end
    end

    describe ".load_default_instruments" do
      it "loads default stats and failbot instances" do
        described_class.send(:load_default_instruments)

        expect(described_class.instrument_plugins[:stats]).to be_a(Hooks::Plugins::Instruments::Stats)
        expect(described_class.instrument_plugins[:failbot]).to be_a(Hooks::Plugins::Instruments::Failbot)
      end

      it "doesn't override custom instruments if already loaded" do
        # Create custom stats
        custom_stats_content = <<~RUBY
        class MyCustomStats < Hooks::Plugins::Instruments::StatsBase
          def record(metric_name, value, tags = {})
            # Custom implementation
          end
        end
      RUBY

        File.write(File.join(test_plugin_dir, "my_custom_stats.rb"), custom_stats_content)
        described_class.send(:load_custom_instrument_plugins, test_plugin_dir)

        # Load defaults
        described_class.send(:load_default_instruments)

        # Should still have custom stats, but default failbot
        expect(described_class.instrument_plugins[:stats]).to be_a(MyCustomStats)
        expect(described_class.instrument_plugins[:failbot]).to be_a(Hooks::Plugins::Instruments::Failbot)
      end
    end

    describe ".valid_instrument_class_name?" do
      it "accepts valid class names" do
        expect(described_class.send(:valid_instrument_class_name?, "CustomStats")).to be true
        expect(described_class.send(:valid_instrument_class_name?, "MyCustomFailbot")).to be true
        expect(described_class.send(:valid_instrument_class_name?, "DatadogStats")).to be true
      end

      it "rejects invalid class names" do
        expect(described_class.send(:valid_instrument_class_name?, "")).to be false
        expect(described_class.send(:valid_instrument_class_name?, "lowercaseClass")).to be false
        expect(described_class.send(:valid_instrument_class_name?, "Class-With-Dashes")).to be false
        expect(described_class.send(:valid_instrument_class_name?, "File")).to be false
      end
    end
  end
end
