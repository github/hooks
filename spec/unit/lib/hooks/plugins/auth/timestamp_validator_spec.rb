# frozen_string_literal: true

require_relative "../../../../spec_helper"

describe Hooks::Plugins::Auth::TimestampValidator do
  let(:validator) { described_class.new }
  let(:log) { instance_double(Logger).as_null_object }

  before(:each) do
    Hooks::Log.instance = log
  end

  describe "#valid?" do
    context "with valid Unix timestamps" do
      it "returns true for current timestamp" do
        timestamp = Time.now.to_i.to_s
        expect(validator.valid?(timestamp, 300)).to be true
      end

      it "returns true for timestamp within tolerance" do
        timestamp = (Time.now.to_i - 100).to_s
        expect(validator.valid?(timestamp, 300)).to be true
      end

      it "returns false for timestamp outside tolerance" do
        timestamp = (Time.now.to_i - 500).to_s
        expect(validator.valid?(timestamp, 300)).to be false
      end
    end

    context "with valid ISO 8601 timestamps" do
      it "returns true for current ISO 8601 timestamp with Z" do
        timestamp = Time.now.utc.strftime("%Y-%m-%dT%H:%M:%SZ")
        expect(validator.valid?(timestamp, 300)).to be true
      end

      it "returns true for current ISO 8601 timestamp with +00:00" do
        timestamp = Time.now.utc.strftime("%Y-%m-%dT%H:%M:%S+00:00")
        expect(validator.valid?(timestamp, 300)).to be true
      end
    end

    context "with invalid timestamps" do
      it "returns false for nil timestamp" do
        expect(validator.valid?(nil, 300)).to be false
      end

      it "returns false for empty timestamp" do
        expect(validator.valid?("", 300)).to be false
      end

      it "returns false for whitespace-only timestamp" do
        expect(validator.valid?("   ", 300)).to be false
      end

      it "returns false for invalid format" do
        expect(validator.valid?("invalid", 300)).to be false
      end
    end
  end

  describe "#parse" do
    context "Unix timestamps" do
      it "parses valid Unix timestamp" do
        unix_timestamp = Time.now.to_i.to_s
        result = validator.parse(unix_timestamp)
        expect(result).to eq(unix_timestamp.to_i)
      end

      it "returns nil for zero timestamp" do
        result = validator.parse("0")
        expect(result).to be_nil
      end

      it "returns nil for negative timestamp" do
        result = validator.parse("-123")
        expect(result).to be_nil
      end

      it "returns nil for timestamp with leading zeros" do
        result = validator.parse("0123456789")
        expect(result).to be_nil
      end
    end

    context "ISO 8601 timestamps" do
      it "parses valid ISO 8601 UTC timestamp with Z" do
        iso_timestamp = "2025-06-12T10:30:00Z"
        result = validator.parse(iso_timestamp)
        expect(result).to eq(Time.parse(iso_timestamp).to_i)
      end

      it "parses valid ISO 8601 UTC timestamp with +00:00" do
        iso_timestamp = "2025-06-12T10:30:00+00:00"
        result = validator.parse(iso_timestamp)
        expect(result).to eq(Time.parse(iso_timestamp).to_i)
      end

      it "returns nil for non-UTC timezone" do
        iso_timestamp = "2025-06-12T10:30:00-05:00"
        result = validator.parse(iso_timestamp)
        expect(result).to be_nil
      end

      it "returns nil for timestamp without timezone" do
        iso_timestamp = "2025-06-12T10:30:00"
        result = validator.parse(iso_timestamp)
        expect(result).to be_nil
      end

      it "returns nil for invalid ISO 8601 format" do
        iso_timestamp = "invalid-timestamp"
        result = validator.parse(iso_timestamp)
        expect(result).to be_nil
      end
    end

    context "security validations" do
      it "returns nil for timestamp with null bytes" do
        result = validator.parse("123\x00456")
        expect(result).to be_nil
      end

      it "returns nil for timestamp with control characters" do
        result = validator.parse("123\x01456")
        expect(result).to be_nil
      end

      it "returns nil for timestamp with whitespace" do
        result = validator.parse(" 1234567890 ")
        expect(result).to be_nil
      end
    end
  end
end
