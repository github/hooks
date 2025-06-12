# frozen_string_literal: true

describe Hooks::Core::ComponentAccess do
  let(:test_class_with_include) do
    Class.new do
      include Hooks::Core::ComponentAccess
    end
  end

  let(:test_class_with_extend) do
    Class.new do
      extend Hooks::Core::ComponentAccess
    end
  end

  describe "when included" do
    let(:instance) { test_class_with_include.new }

    describe "#log" do
      it "provides access to global logger" do
        expect(instance.log).to be(Hooks::Log.instance)
      end
    end

    describe "#stats" do
      it "provides access to global stats" do
        expect(instance.stats).to be_a(Hooks::Plugins::Instruments::Stats)
        expect(instance.stats).to eq(Hooks::Core::GlobalComponents.stats)
      end
    end

    describe "#failbot" do
      it "provides access to global failbot" do
        expect(instance.failbot).to be_a(Hooks::Plugins::Instruments::Failbot)
        expect(instance.failbot).to eq(Hooks::Core::GlobalComponents.failbot)
      end
    end
  end

  describe "when extended" do
    describe ".log" do
      it "provides access to global logger" do
        expect(test_class_with_extend.log).to be(Hooks::Log.instance)
      end
    end

    describe ".stats" do
      it "provides access to global stats" do
        expect(test_class_with_extend.stats).to be_a(Hooks::Plugins::Instruments::Stats)
        expect(test_class_with_extend.stats).to eq(Hooks::Core::GlobalComponents.stats)
      end
    end

    describe ".failbot" do
      it "provides access to global failbot" do
        expect(test_class_with_extend.failbot).to be_a(Hooks::Plugins::Instruments::Failbot)
        expect(test_class_with_extend.failbot).to eq(Hooks::Core::GlobalComponents.failbot)
      end
    end
  end
end