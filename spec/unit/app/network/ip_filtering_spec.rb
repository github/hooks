# frozen_string_literal: true

require_relative "../../../unit/spec_helper"
require_relative "../../../../lib/hooks/core/network/ip_filtering"

describe Hooks::Core::Network::IpFiltering do
  describe ".ip_filtering!" do
    let(:headers) { { "X-Forwarded-For" => "192.168.1.100" } }
    let(:endpoint_config) { {} }
    let(:global_config) { {} }
    let(:request_context) { { request_id: "test-123" } }
    let(:env) { {} }

    context "when no IP filtering is configured" do
      it "does not raise an error" do
        expect {
          described_class.ip_filtering!(headers, endpoint_config, global_config, request_context, env)
        }.not_to raise_error
      end
    end

    context "with allowlist configuration" do
      let(:endpoint_config) do
        {
          ip_filtering: {
            allowlist: ["192.168.1.100", "10.0.0.0/8"]
          }
        }
      end

      context "when client IP is in allowlist" do
        it "does not raise an error" do
          expect {
            described_class.ip_filtering!(headers, endpoint_config, global_config, request_context, env)
          }.not_to raise_error
        end
      end

      context "when client IP is in CIDR range" do
        let(:headers) { { "X-Forwarded-For" => "10.1.2.3" } }

        it "does not raise an error" do
          expect {
            described_class.ip_filtering!(headers, endpoint_config, global_config, request_context, env)
          }.not_to raise_error
        end
      end

      context "when client IP is not in allowlist" do
        let(:headers) { { "X-Forwarded-For" => "203.0.113.1" } }

        it "raises an error with 403 status" do
          expect {
            described_class.ip_filtering!(headers, endpoint_config, global_config, request_context, env)
          }.to raise_error(Hooks::Plugins::Handlers::Error) do |error|
            expect(error.status).to eq(403)
            expect(error.body[:error]).to eq("ip_filtering_failed")
            expect(error.body[:message]).to eq("IP address not allowed")
            expect(error.body[:request_id]).to eq("test-123")
          end
        end
      end
    end

    context "with blocklist configuration" do
      let(:endpoint_config) do
        {
          ip_filtering: {
            blocklist: ["192.168.1.100", "203.0.113.0/24"]
          }
        }
      end

      context "when client IP is not in blocklist" do
        let(:headers) { { "X-Forwarded-For" => "10.0.0.1" } }

        it "does not raise an error" do
          expect {
            described_class.ip_filtering!(headers, endpoint_config, global_config, request_context, env)
          }.not_to raise_error
        end
      end

      context "when client IP is in blocklist" do
        it "raises an error with 403 status" do
          expect {
            described_class.ip_filtering!(headers, endpoint_config, global_config, request_context, env)
          }.to raise_error(Hooks::Plugins::Handlers::Error) do |error|
            expect(error.status).to eq(403)
            expect(error.body[:error]).to eq("ip_filtering_failed")
          end
        end
      end

      context "when client IP is in blocklist CIDR range" do
        let(:headers) { { "X-Forwarded-For" => "203.0.113.50" } }

        it "raises an error with 403 status" do
          expect {
            described_class.ip_filtering!(headers, endpoint_config, global_config, request_context, env)
          }.to raise_error(Hooks::Plugins::Handlers::Error) do |error|
            expect(error.status).to eq(403)
          end
        end
      end
    end

    context "with both allowlist and blocklist" do
      let(:endpoint_config) do
        {
          ip_filtering: {
            allowlist: ["192.168.1.0/24"],
            blocklist: ["192.168.1.100"]
          }
        }
      end

      context "when IP is in allowlist but also in blocklist" do
        it "raises an error (blocklist takes precedence)" do
          expect {
            described_class.ip_filtering!(headers, endpoint_config, global_config, request_context, env)
          }.to raise_error(Hooks::Plugins::Handlers::Error) do |error|
            expect(error.status).to eq(403)
          end
        end
      end

      context "when IP is in allowlist and not in blocklist" do
        let(:headers) { { "X-Forwarded-For" => "192.168.1.50" } }

        it "does not raise an error" do
          expect {
            described_class.ip_filtering!(headers, endpoint_config, global_config, request_context, env)
          }.not_to raise_error
        end
      end
    end

    context "with custom IP header" do
      let(:endpoint_config) do
        {
          ip_filtering: {
            ip_header: "X-Real-IP",
            allowlist: ["192.168.1.100"]
          }
        }
      end
      let(:headers) { { "X-Real-IP" => "192.168.1.100", "X-Forwarded-For" => "203.0.113.1" } }

      it "uses the custom header instead of X-Forwarded-For" do
        expect {
          described_class.ip_filtering!(headers, endpoint_config, global_config, request_context, env)
        }.not_to raise_error
      end
    end

    context "with case-insensitive headers" do
      let(:endpoint_config) do
        {
          ip_filtering: {
            allowlist: ["192.168.1.100"]
          }
        }
      end
      let(:headers) { { "x-forwarded-for" => "192.168.1.100" } }

      it "finds the header regardless of case" do
        expect {
          described_class.ip_filtering!(headers, endpoint_config, global_config, request_context, env)
        }.not_to raise_error
      end
    end

    context "with multiple IPs in X-Forwarded-For" do
      let(:endpoint_config) do
        {
          ip_filtering: {
            allowlist: ["192.168.1.100"]
          }
        }
      end
      let(:headers) { { "X-Forwarded-For" => "192.168.1.100, 10.0.0.1, 203.0.113.1" } }

      it "uses the first IP (original client)" do
        expect {
          described_class.ip_filtering!(headers, endpoint_config, global_config, request_context, env)
        }.not_to raise_error
      end
    end

    context "with global configuration" do
      let(:global_config) do
        {
          ip_filtering: {
            allowlist: ["192.168.1.100"]
          }
        }
      end

      it "uses global configuration when endpoint config is not set" do
        expect {
          described_class.ip_filtering!(headers, endpoint_config, global_config, request_context, env)
        }.not_to raise_error
      end
    end

    context "with endpoint configuration overriding global" do
      let(:global_config) do
        {
          ip_filtering: {
            allowlist: ["10.0.0.1"]
          }
        }
      end
      let(:endpoint_config) do
        {
          ip_filtering: {
            allowlist: ["192.168.1.100"]
          }
        }
      end

      it "uses endpoint configuration over global" do
        expect {
          described_class.ip_filtering!(headers, endpoint_config, global_config, request_context, env)
        }.not_to raise_error
      end
    end

    context "with invalid IP addresses" do
      let(:endpoint_config) do
        {
          ip_filtering: {
            allowlist: ["192.168.1.100"]
          }
        }
      end
      let(:headers) { { "X-Forwarded-For" => "invalid-ip" } }

      it "raises an error for invalid client IP" do
        expect {
          described_class.ip_filtering!(headers, endpoint_config, global_config, request_context, env)
        }.to raise_error(Hooks::Plugins::Handlers::Error) do |error|
          expect(error.status).to eq(403)
        end
      end
    end

    context "when no IP header is present" do
      let(:endpoint_config) do
        {
          ip_filtering: {
            allowlist: ["192.168.1.100"]
          }
        }
      end
      let(:headers) { {} }

      it "does not raise an error (no filtering applied)" do
        expect {
          described_class.ip_filtering!(headers, endpoint_config, global_config, request_context, env)
        }.not_to raise_error
      end
    end

    context "when custom IP header is not found" do
      let(:endpoint_config) do
        {
          ip_filtering: {
            ip_header: "X-Real-IP",
            allowlist: ["192.168.1.100"]
          }
        }
      end
      let(:headers) { { "X-Forwarded-For" => "192.168.1.100" } }

      it "does not raise an error (no filtering applied)" do
        expect {
          described_class.ip_filtering!(headers, endpoint_config, global_config, request_context, env)
        }.not_to raise_error
      end
    end

    context "when IP header has empty value" do
      let(:endpoint_config) do
        {
          ip_filtering: {
            allowlist: ["192.168.1.100"]
          }
        }
      end
      let(:headers) { { "X-Forwarded-For" => "" } }

      it "does not raise an error (no filtering applied)" do
        expect {
          described_class.ip_filtering!(headers, endpoint_config, global_config, request_context, env)
        }.not_to raise_error
      end
    end

    context "when IP header has whitespace only value" do
      let(:endpoint_config) do
        {
          ip_filtering: {
            allowlist: ["192.168.1.100"]
          }
        }
      end
      let(:headers) { { "X-Forwarded-For" => "   " } }

      it "does not raise an error (no filtering applied)" do
        expect {
          described_class.ip_filtering!(headers, endpoint_config, global_config, request_context, env)
        }.not_to raise_error
      end
    end

    context "with invalid IP patterns in configuration" do
      let(:endpoint_config) do
        {
          ip_filtering: {
            allowlist: ["192.168.1.100", "invalid-pattern", "10.0.0.0/8"]
          }
        }
      end
      let(:headers) { { "X-Forwarded-For" => "10.0.0.1" } }

      it "skips invalid patterns and processes valid ones" do
        expect {
          described_class.ip_filtering!(headers, endpoint_config, global_config, request_context, env)
        }.not_to raise_error
      end
    end

    context "with string keys in request_context" do
      let(:endpoint_config) do
        {
          ip_filtering: {
            allowlist: ["192.168.1.100"]
          }
        }
      end
      let(:request_context) { { "request_id" => "test-string-key" } }
      let(:headers) { { "X-Forwarded-For" => "203.0.113.1" } }

      it "raises an error and extracts request_id correctly" do
        expect {
          described_class.ip_filtering!(headers, endpoint_config, global_config, request_context, env)
        }.to raise_error(Hooks::Plugins::Handlers::Error) do |error|
          expect(error.status).to eq(403)
          expect(error.body[:request_id]).to eq("test-string-key")
        end
      end
    end

    context "with blocklist only configuration" do
      let(:endpoint_config) do
        {
          ip_filtering: {
            blocklist: ["203.0.113.0/24"]
          }
        }
      end
      let(:headers) { { "X-Forwarded-For" => "192.168.1.100" } }

      it "allows IPs not in blocklist when no allowlist is defined" do
        expect {
          described_class.ip_filtering!(headers, endpoint_config, global_config, request_context, env)
        }.not_to raise_error
      end
    end

    context "when IP header has nil value after split" do
      let(:endpoint_config) do
        {
          ip_filtering: {
            allowlist: ["192.168.1.100"]
          }
        }
      end
      let(:headers) { { "X-Forwarded-For" => "," } }

      it "does not raise an error (no filtering applied)" do
        expect {
          described_class.ip_filtering!(headers, endpoint_config, global_config, request_context, env)
        }.not_to raise_error
      end
    end
  end
end
