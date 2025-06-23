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

  after do
    Hooks::Core::GlobalComponents.reset
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

    describe "user component access" do
      context "when user components are registered" do
        let(:publisher) { double("Publisher") }
        let(:callable_service) { ->(data) { "Called with #{data}" } }

        before do
          Hooks::Core::GlobalComponents.register_extra_components({
            publisher: publisher,
            callable_service: callable_service
          })
        end

        it "provides access to user components as methods" do
          expect(instance.publisher).to eq(publisher)
          expect(instance.callable_service).to eq(callable_service)
        end

        it "calls user components with arguments when provided" do
          expect(callable_service).to receive(:call).with("test_data")
          instance.callable_service("test_data")
        end

        it "calls user components with keyword arguments when provided" do
          expect(callable_service).to receive(:call).with(data: "test")
          instance.callable_service(data: "test")
        end

        it "calls user components with block when provided" do
          block = proc { "test block" }
          expect(callable_service).to receive(:call) do |*args, &passed_block|
            expect(passed_block).to eq(block)
          end
          instance.callable_service(&block)
        end

        it "responds to user component names" do
          expect(instance.respond_to?(:publisher)).to be true
          expect(instance.respond_to?(:callable_service)).to be true
          expect(instance.respond_to?(:nonexistent)).to be false
        end
      end

      context "when no user components are registered" do
        it "raises NoMethodError for undefined methods" do
          expect { instance.nonexistent_method }.to raise_error(NoMethodError)
        end

        it "does not respond to non-existent methods" do
          expect(instance.respond_to?(:nonexistent_method)).to be false
        end
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
