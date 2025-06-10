# frozen_string_literal: true

# Example handler for Team 1 webhooks
class Team1Handler < Hooks::Handlers::Base
  # Process Team 1 webhook
  #
  # @param payload [Hash, String] Webhook payload
  # @param headers [Hash<String, String>] HTTP headers
  # @param config [Hash] Endpoint configuration
  # @return [Hash] Response data
  def call(payload:, headers:, config:)
    # Log the webhook receipt
    puts "Team1Handler: Received webhook for #{config.dig(:opts, :teams)&.join(', ')}"

    # Process the payload based on type
    if payload.is_a?(Hash)
      event_type = payload[:event_type] || "unknown"

      case event_type
      when "deployment"
        handle_deployment(payload, config)
      when "alert"
        handle_alert(payload, config)
      else
        handle_generic(payload, config)
      end
    else
      # Handle raw string payload
      {
        status: "processed",
        handler: "Team1Handler",
        message: "Raw payload processed",
        payload_size: payload.length,
        environment: config.dig(:opts, :env),
        timestamp: Time.now.iso8601
      }
    end
  end

  private

  # Handle deployment events
  #
  # @param payload [Hash] Deployment payload
  # @param config [Hash] Configuration
  # @return [Hash] Response
  def handle_deployment(payload, config)
    {
      status: "deployment_processed",
      handler: "Team1Handler",
      deployment_id: payload["deployment_id"],
      environment: payload["environment"] || config.dig(:opts, :env),
      teams_notified: config.dig(:opts, :teams),
      timestamp: Time.now.iso8601
    }
  end

  # Handle alert events
  #
  # @param payload [Hash] Alert payload
  # @param config [Hash] Configuration
  # @return [Hash] Response
  def handle_alert(payload, config)
    alert_level = payload["level"] || "info"

    # In a real implementation, you might send notifications here
    # notify_teams(payload, config.dig(:opts, :notify_channels))

    {
      status: "alert_processed",
      handler: "Team1Handler",
      alert_id: payload["alert_id"],
      level: alert_level,
      channels_notified: config.dig(:opts, :notify_channels),
      timestamp: Time.now.iso8601
    }
  end

  # Handle generic events
  #
  # @param payload [Hash] Generic payload
  # @param config [Hash] Configuration
  # @return [Hash] Response
  def handle_generic(payload, config)
    {
      status: "generic_processed",
      handler: "Team1Handler",
      event_type: payload["event_type"],
      environment: config.dig(:opts, :env),
      timestamp: Time.now.iso8601
    }
  end
end
