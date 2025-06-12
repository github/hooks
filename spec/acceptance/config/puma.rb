# frozen_string_literal: true

require "time"
require "json"

bind "tcp://0.0.0.0:8080"

# single mode: https://github.com/puma/puma/blob/master/docs/deployment.md#single-vs-cluster-mode
workers 0

threads 0, 16 # the default

log_formatter do |msg|
  timestamp = Time.now.strftime("%Y-%m-%dT%H:%M:%S.%L%z")
  {
    time: timestamp,
    level: ENV.fetch("LOG_LEVEL", "info").downcase,
    progname: "puma",
    msg: msg.rstrip
  }.to_json
end
