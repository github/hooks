# frozen_string_literal: true

require_relative "../../../spec_helper"

describe Hooks::Plugins::Lifecycle do
  let(:plugin) { described_class.new }
  let(:env) { { "REQUEST_METHOD" => "POST", "PATH_INFO" => "/webhook" } }
  let(:response) { { "status" => "success", "data" => "processed" } }
  let(:exception) { StandardError.new("Test error") }

  describe "#on_request" do
    it "can be called without error" do
      expect { plugin.on_request(env) }.not_to raise_error
    end

    it "returns nil by default" do
      result = plugin.on_request(env)
      expect(result).to be_nil
    end

    it "accepts any environment hash" do
      empty_env = {}
      complex_env = {
        "REQUEST_METHOD" => "POST",
        "PATH_INFO" => "/webhook/test",
        "HTTP_USER_AGENT" => "TestAgent/1.0",
        "CONTENT_TYPE" => "application/json"
      }

      expect { plugin.on_request(empty_env) }.not_to raise_error
      expect { plugin.on_request(complex_env) }.not_to raise_error
    end

    it "can be overridden in subclasses" do
      custom_plugin_class = Class.new(described_class) do
        def on_request(env)
          @request_called = true
          @received_env = env
          "request processed"
        end

        attr_reader :request_called, :received_env
      end

      plugin = custom_plugin_class.new
      result = plugin.on_request(env)

      expect(plugin.request_called).to be true
      expect(plugin.received_env).to eq(env)
      expect(result).to eq("request processed")
    end
  end

  describe "#on_response" do
    it "can be called without error" do
      expect { plugin.on_response(env, response) }.not_to raise_error
    end

    it "returns nil by default" do
      result = plugin.on_response(env, response)
      expect(result).to be_nil
    end

    it "accepts any environment and response" do
      empty_env = {}
      empty_response = {}
      nil_response = nil

      expect { plugin.on_response(empty_env, empty_response) }.not_to raise_error
      expect { plugin.on_response(env, nil_response) }.not_to raise_error
    end

    it "can be overridden in subclasses" do
      custom_plugin_class = Class.new(described_class) do
        def on_response(env, response)
          @response_called = true
          @received_env = env
          @received_response = response
          "response processed"
        end

        attr_reader :response_called, :received_env, :received_response
      end

      plugin = custom_plugin_class.new
      result = plugin.on_response(env, response)

      expect(plugin.response_called).to be true
      expect(plugin.received_env).to eq(env)
      expect(plugin.received_response).to eq(response)
      expect(result).to eq("response processed")
    end
  end

  describe "#on_error" do
    it "can be called without error" do
      expect { plugin.on_error(exception, env) }.not_to raise_error
    end

    it "returns nil by default" do
      result = plugin.on_error(exception, env)
      expect(result).to be_nil
    end

    it "accepts any exception and environment" do
      runtime_error = RuntimeError.new("Runtime error")
      argument_error = ArgumentError.new("Argument error")
      empty_env = {}

      expect { plugin.on_error(runtime_error, env) }.not_to raise_error
      expect { plugin.on_error(argument_error, empty_env) }.not_to raise_error
    end

    it "can be overridden in subclasses" do
      custom_plugin_class = Class.new(described_class) do
        def on_error(exception, env)
          @error_called = true
          @received_exception = exception
          @received_env = env
          "error handled"
        end

        attr_reader :error_called, :received_exception, :received_env
      end

      plugin = custom_plugin_class.new
      result = plugin.on_error(exception, env)

      expect(plugin.error_called).to be true
      expect(plugin.received_exception).to eq(exception)
      expect(plugin.received_env).to eq(env)
      expect(result).to eq("error handled")
    end
  end

  describe "inheritance" do
    it "can be inherited" do
      child_class = Class.new(described_class)
      expect(child_class.ancestors).to include(described_class)
    end

    it "maintains all lifecycle methods in subclasses" do
      child_class = Class.new(described_class) do
        def on_request(env)
          "child_request"
        end

        def on_response(env, response)
          "child_response"
        end

        def on_error(exception, env)
          "child_error"
        end
      end

      plugin = child_class.new

      expect(plugin.on_request(env)).to eq("child_request")
      expect(plugin.on_response(env, response)).to eq("child_response")
      expect(plugin.on_error(exception, env)).to eq("child_error")
    end

    it "allows selective overriding of lifecycle methods" do
      partial_plugin_class = Class.new(described_class) do
        def on_request(env)
          "overridden request"
        end
        # on_response and on_error use default implementation
      end

      plugin = partial_plugin_class.new

      expect(plugin.on_request(env)).to eq("overridden request")
      expect(plugin.on_response(env, response)).to be_nil
      expect(plugin.on_error(exception, env)).to be_nil
    end
  end

  describe "method signatures" do
    it "on_request accepts one parameter" do
      method = described_class.instance_method(:on_request)
      expect(method.arity).to eq(1)
      expect(method.parameters).to eq([[:req, :env]])
    end

    it "on_response accepts two parameters" do
      method = described_class.instance_method(:on_response)
      expect(method.arity).to eq(2)
      expect(method.parameters).to eq([[:req, :env], [:req, :response]])
    end

    it "on_error accepts two parameters" do
      method = described_class.instance_method(:on_error)
      expect(method.arity).to eq(2)
      expect(method.parameters).to eq([[:req, :exception], [:req, :env]])
    end
  end

  describe "instance creation" do
    it "can be instantiated" do
      expect { described_class.new }.not_to raise_error
    end

    it "creates unique instances" do
      plugin1 = described_class.new
      plugin2 = described_class.new

      expect(plugin1).not_to be(plugin2)
    end
  end

  describe "integration example" do
    it "demonstrates typical plugin usage" do
      logging_plugin_class = Class.new(described_class) do
        attr_reader :logs

        def initialize
          @logs = []
        end

        def on_request(env)
          @logs << "Request: #{env['REQUEST_METHOD']} #{env['PATH_INFO']}"
        end

        def on_response(env, response)
          @logs << "Response: #{response&.dig('status') || 'unknown'}"
        end

        def on_error(exception, env)
          @logs << "Error: #{exception.message}"
        end
      end

      plugin = logging_plugin_class.new

      # Simulate request lifecycle
      plugin.on_request(env)
      plugin.on_response(env, response)
      plugin.on_error(exception, env)

      expect(plugin.logs).to eq([
        "Request: POST /webhook",
        "Response: success",
        "Error: Test error"
      ])
    end
  end

  describe "global component access" do
    describe "#stats" do
      it "provides access to global stats" do
        expect(plugin.stats).to be_a(Hooks::Plugins::Instruments::Stats)
        expect(plugin.stats).to eq(Hooks::Core::GlobalComponents.stats)
      end
    end

    describe "#failbot" do
      it "provides access to global failbot" do
        expect(plugin.failbot).to be_a(Hooks::Plugins::Instruments::Failbot)
        expect(plugin.failbot).to eq(Hooks::Core::GlobalComponents.failbot)
      end
    end

    it "allows stats and failbot usage in subclasses" do
      metrics_plugin_class = Class.new(described_class) do
        def initialize
          @recorded_metrics = []
          @reported_errors = []
        end

        def on_request(env)
          stats.increment("lifecycle.request", { path: env["PATH_INFO"] })
        end

        def on_error(exception, env)
          failbot.report(exception, { path: env["PATH_INFO"] })
        end

        attr_reader :recorded_metrics, :reported_errors
      end

      # Create custom stats and failbot for testing
      custom_stats = Class.new(Hooks::Core::Stats) do
        def initialize(collector)
          @collector = collector
        end

        def increment(metric_name, tags = {})
          @collector << { type: :increment, metric: metric_name, tags: }
        end
      end

      custom_failbot = Class.new(Hooks::Core::Failbot) do
        def initialize(collector)
          @collector = collector
        end

        def report(error_or_message, context = {})
          @collector << { type: :report, error: error_or_message, context: }
        end
      end

      collected_data = []
      original_stats = Hooks::Core::GlobalComponents.stats
      original_failbot = Hooks::Core::GlobalComponents.failbot

      begin
        Hooks::Core::GlobalComponents.stats = custom_stats.new(collected_data)
        Hooks::Core::GlobalComponents.failbot = custom_failbot.new(collected_data)

        plugin = metrics_plugin_class.new
        plugin.on_request(env)
        plugin.on_error(exception, env)

        expect(collected_data).to match_array([
          { type: :increment, metric: "lifecycle.request", tags: { path: "/webhook" } },
          { type: :report, error: exception, context: { path: "/webhook" } }
        ])
      ensure
        Hooks::Core::GlobalComponents.stats = original_stats
        Hooks::Core::GlobalComponents.failbot = original_failbot
      end
    end
  end
end
