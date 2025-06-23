# frozen_string_literal: true

describe Hooks::Core::GlobalComponents do
  after do
    described_class.reset
  end

  describe ".register_extra_components" do
    it "registers user-defined components" do
      publisher = double("Publisher")
      service = double("Service")

      described_class.register_extra_components({
        publisher: publisher,
        service: service
      })

      expect(described_class.get_extra_component(:publisher)).to eq(publisher)
      expect(described_class.get_extra_component("service")).to eq(service)
    end

    it "handles empty components hash" do
      described_class.register_extra_components({})
      expect(described_class.extra_component_names).to be_empty
    end
  end

  describe ".get_extra_component" do
    before do
      described_class.register_extra_components({
        publisher: "test_publisher",
        "string_key" => "test_service"
      })
    end

    it "retrieves component by symbol key" do
      expect(described_class.get_extra_component(:publisher)).to eq("test_publisher")
    end

    it "retrieves component by string key" do
      expect(described_class.get_extra_component("string_key")).to eq("test_service")
    end

    it "returns nil for non-existent component" do
      expect(described_class.get_extra_component(:nonexistent)).to be_nil
    end
  end

  describe ".extra_component_names" do
    it "returns all component names as symbols" do
      described_class.register_extra_components({
        publisher: "test_publisher",
        "service" => "test_service"
      })

      names = described_class.extra_component_names
      expect(names).to contain_exactly(:publisher, :service)
    end
  end

  describe ".extra_component_exists?" do
    before do
      described_class.register_extra_components({
        publisher: "test_publisher",
        "string_key" => "test_service"
      })
    end

    it "returns true for existing component with symbol key" do
      expect(described_class.extra_component_exists?(:publisher)).to be true
    end

    it "returns true for existing component with string key" do
      expect(described_class.extra_component_exists?("string_key")).to be true
    end

    it "returns false for non-existent component" do
      expect(described_class.extra_component_exists?(:nonexistent)).to be false
    end
  end

  describe ".stats" do
    it "returns a Stats instance by default" do
      expect(described_class.stats).to be_a(Hooks::Plugins::Instruments::Stats)
    end

    it "can be set to a custom stats instance" do
      custom_stats = double("CustomStats")
      original_stats = described_class.stats

      described_class.stats = custom_stats
      expect(described_class.stats).to eq(custom_stats)

      # Restore original for other tests
      described_class.stats = original_stats
    end
  end

  describe ".failbot" do
    it "returns a Failbot instance by default" do
      expect(described_class.failbot).to be_a(Hooks::Plugins::Instruments::Failbot)
    end

    it "can be set to a custom failbot instance" do
      custom_failbot = double("CustomFailbot")
      original_failbot = described_class.failbot

      described_class.failbot = custom_failbot
      expect(described_class.failbot).to eq(custom_failbot)

      # Restore original for other tests
      described_class.failbot = original_failbot
    end
  end

  describe ".reset" do
    it "resets all components to default instances" do
      # Set custom instances
      custom_stats = double("CustomStats")
      custom_failbot = double("CustomFailbot")
      described_class.stats = custom_stats
      described_class.failbot = custom_failbot
      described_class.register_extra_components({ publisher: "test" })

      # Reset
      described_class.reset

      # Verify they are back to default instances
      expect(described_class.stats).to be_a(Hooks::Plugins::Instruments::Stats)
      expect(described_class.failbot).to be_a(Hooks::Plugins::Instruments::Failbot)
      expect(described_class.get_extra_component(:publisher)).to be_nil
      expect(described_class.extra_component_names).to be_empty
    end
  end

  describe "thread safety" do
    it "handles concurrent access to user components safely" do
      threads = []
      results = []
      mutex = Mutex.new

      # Start multiple threads that register and access components concurrently
      10.times do |i|
        threads << Thread.new do
          # Each thread registers a component with a unique name
          described_class.register_extra_components({ "component_#{i}": "value_#{i}" })

          # Then tries to read it back
          value = described_class.get_extra_component("component_#{i}")
          mutex.synchronize { results << value }
        end
      end

      # Wait for all threads to complete
      threads.each(&:join)

      # Verify all components were registered and retrieved correctly
      expect(results.size).to eq(10)
      results.each_with_index do |result, i|
        expect(result).to eq("value_#{i}")
      end
    end
  end
end
