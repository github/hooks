# frozen_string_literal: true

require_relative "../lib/hooks/handlers/base"

# Example handler for GitHub webhooks
class GitHubHandler < Hooks::Handlers::Base
  # Process GitHub webhook
  #
  # @param payload [Hash, String] GitHub webhook payload
  # @param headers [Hash<String, String>] HTTP headers
  # @param config [Hash] Endpoint configuration
  # @return [Hash] Response data
  def call(payload:, headers:, config:)
    # GitHub sends event type in header
    event_type = headers["X-GitHub-Event"] || "unknown"

    puts "GitHubHandler: Received #{event_type} event"

    return handle_raw_payload(payload, config) unless payload.is_a?(Hash)

    case event_type
    when "push"
      handle_push_event(payload, config)
    when "pull_request"
      handle_pull_request_event(payload, config)
    when "issues"
      handle_issues_event(payload, config)
    when "ping"
      handle_ping_event(payload, config)
    else
      handle_unknown_event(payload, event_type, config)
    end
  end

  private

  # Handle raw string payload
  #
  # @param payload [String] Raw payload
  # @param config [Hash] Configuration
  # @return [Hash] Response
  def handle_raw_payload(payload, config)
    {
      status: "raw_payload_processed",
      handler: "GitHubHandler",
      payload_size: payload.length,
      repository: config.dig(:opts, :repository),
      timestamp: Time.now.iso8601
    }
  end

  # Handle push events
  #
  # @param payload [Hash] Push event payload
  # @param config [Hash] Configuration
  # @return [Hash] Response
  def handle_push_event(payload, config)
    ref = payload["ref"]
    branch = ref&.split("/")&.last
    commits_count = payload.dig("commits")&.length || 0

    # Check if branch is in filter
    branch_filter = config.dig(:opts, :branch_filter)
    if branch_filter && !branch_filter.include?(branch)
      return {
        status: "ignored",
        handler: "GitHubHandler",
        reason: "branch_not_in_filter",
        branch: branch,
        filter: branch_filter,
        timestamp: Time.now.iso8601
      }
    end

    {
      status: "push_processed",
      handler: "GitHubHandler",
      repository: payload.dig("repository", "full_name"),
      branch: branch,
      commits_count: commits_count,
      pusher: payload.dig("pusher", "name"),
      timestamp: Time.now.iso8601
    }
  end

  # Handle pull request events
  #
  # @param payload [Hash] Pull request event payload
  # @param config [Hash] Configuration
  # @return [Hash] Response
  def handle_pull_request_event(payload, config)
    action = payload["action"]
    pr_number = payload.dig("pull_request", "number")
    pr_title = payload.dig("pull_request", "title")

    {
      status: "pull_request_processed",
      handler: "GitHubHandler",
      action: action,
      repository: payload.dig("repository", "full_name"),
      pr_number: pr_number,
      pr_title: pr_title,
      author: payload.dig("pull_request", "user", "login"),
      timestamp: Time.now.iso8601
    }
  end

  # Handle issues events
  #
  # @param payload [Hash] Issues event payload
  # @param config [Hash] Configuration
  # @return [Hash] Response
  def handle_issues_event(payload, config)
    action = payload["action"]
    issue_number = payload.dig("issue", "number")
    issue_title = payload.dig("issue", "title")

    {
      status: "issue_processed",
      handler: "GitHubHandler",
      action: action,
      repository: payload.dig("repository", "full_name"),
      issue_number: issue_number,
      issue_title: issue_title,
      author: payload.dig("issue", "user", "login"),
      timestamp: Time.now.iso8601
    }
  end

  # Handle ping events (webhook test)
  #
  # @param payload [Hash] Ping event payload
  # @param config [Hash] Configuration
  # @return [Hash] Response
  def handle_ping_event(payload, config)
    {
      status: "ping_acknowledged",
      handler: "GitHubHandler",
      repository: payload.dig("repository", "full_name"),
      hook_id: payload.dig("hook", "id"),
      zen: payload["zen"],
      timestamp: Time.now.iso8601
    }
  end

  # Handle unknown events
  #
  # @param payload [Hash] Event payload
  # @param event_type [String] Event type
  # @param config [Hash] Configuration
  # @return [Hash] Response
  def handle_unknown_event(payload, event_type, config)
    {
      status: "unknown_event_processed",
      handler: "GitHubHandler",
      event_type: event_type,
      repository: payload.dig("repository", "full_name"),
      supported_events: config.dig(:opts, :events),
      timestamp: Time.now.iso8601
    }
  end
end
