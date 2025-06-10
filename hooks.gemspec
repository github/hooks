# frozen_string_literal: true

require_relative "lib/hooks/version"

Gem::Specification.new do |spec|
  spec.name          = "hooks-ruby"
  spec.version       = Hooks::VERSION
  spec.authors       = ["github", "GrantBirki"]
  spec.license       = "MIT"

  spec.summary       = "A Pluggable Webhook Server Framework written in Ruby"
  spec.description   = <<~SPEC_DESC
    A Pluggable Webhook Server Framework written in Ruby
  SPEC_DESC

  spec.homepage = "https://github.com/github/hooks"
  spec.metadata = {
    "bug_tracker_uri" => "https://github.com/github/hooks/issues"
  }

  spec.add_dependency "redacting-logger", "~> 1.5"
  spec.add_dependency "retryable", "~> 3.0", ">= 3.0.5"
  spec.add_dependency "dry-schema", "~> 1.14", ">= 1.14.1"
  spec.add_dependency "grape", "~> 2.3"
  spec.add_dependency "grape-swagger", "~> 2.1", ">= 2.1.2"
  spec.add_dependency "puma", "~> 6.6"

  spec.required_ruby_version = Gem::Requirement.new(">= 3.2.2")

  spec.files = %w[LICENSE README.md hooks.gemspec config.ru]
  spec.files += Dir.glob("lib/**/*.rb")
  spec.files += Dir.glob("bin/*")
  spec.bindir = "bin"
  spec.executables = ["hooks"]
  spec.require_paths = ["lib"]
end
