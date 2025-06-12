# frozen_string_literal: true

describe Hooks::Core::Stats do
  let(:stats) { described_class.new }

  describe "#record" do
    it "can be called without error" do
      expect { stats.record("test.metric", 123) }.not_to raise_error
    end

    it "accepts tags parameter" do
      expect { stats.record("test.metric", 456, { handler: "TestHandler" }) }.not_to raise_error
    end

    it "can be overridden in subclasses" do
      custom_stats_class = Class.new(described_class) do
        def initialize
          @recorded_metrics = []
        end

        def record(metric_name, value, tags = {})
          @recorded_metrics << { metric: metric_name, value:, tags: }
        end

        attr_reader :recorded_metrics
      end

      custom_stats = custom_stats_class.new
      custom_stats.record("test.metric", 789, { test: true })

      expect(custom_stats.recorded_metrics).to eq([
        { metric: "test.metric", value: 789, tags: { test: true } }
      ])
    end
  end

  describe "#increment" do
    it "can be called without error" do
      expect { stats.increment("test.counter") }.not_to raise_error
    end

    it "accepts tags parameter" do
      expect { stats.increment("test.counter", { handler: "TestHandler" }) }.not_to raise_error
    end
  end

  describe "#timing" do
    it "can be called without error" do
      expect { stats.timing("test.timer", 1.5) }.not_to raise_error
    end

    it "accepts tags parameter" do
      expect { stats.timing("test.timer", 2.3, { handler: "TestHandler" }) }.not_to raise_error
    end
  end

  describe "#measure" do
    it "can measure block execution" do
      result = stats.measure("test.execution") { "block result" }
      expect(result).to eq("block result")
    end

    it "accepts tags parameter" do
      result = stats.measure("test.execution", { handler: "TestHandler" }) { 42 }
      expect(result).to eq(42)
    end

    it "measures timing in subclasses" do
      timed_stats_class = Class.new(described_class) do
        def initialize
          @timings = []
        end

        def timing(metric_name, duration, tags = {})
          @timings << { metric: metric_name, duration:, tags: }
        end

        attr_reader :timings
      end

      timed_stats = timed_stats_class.new
      result = timed_stats.measure("test.block") { "measured" }

      expect(result).to eq("measured")
      expect(timed_stats.timings.size).to eq(1)
      expect(timed_stats.timings[0][:metric]).to eq("test.block")
      expect(timed_stats.timings[0][:duration]).to be_a(Numeric)
      expect(timed_stats.timings[0][:duration]).to be >= 0
    end
  end
end
