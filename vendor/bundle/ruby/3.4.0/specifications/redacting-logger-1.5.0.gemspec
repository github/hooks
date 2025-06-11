# -*- encoding: utf-8 -*-
# stub: redacting-logger 1.5.0 ruby lib

Gem::Specification.new do |s|
  s.name = "redacting-logger".freeze
  s.version = "1.5.0".freeze

  s.required_rubygems_version = Gem::Requirement.new(">= 0".freeze) if s.respond_to? :required_rubygems_version=
  s.metadata = { "bug_tracker_uri" => "https://github.com/github/redacting-logger/issues", "documentation_uri" => "https://github.com/github/redacting-logger", "source_code_uri" => "https://github.com/github/redacting-logger" } if s.respond_to? :metadata=
  s.require_paths = ["lib".freeze]
  s.authors = ["GitHub".freeze, "GitHub Security".freeze]
  s.date = "2025-05-28"
  s.description = "A redacting Ruby logger to prevent the leaking of secrets via logs\n".freeze
  s.email = "opensource@github.com".freeze
  s.homepage = "https://github.com/github/redacting-logger".freeze
  s.licenses = ["MIT".freeze]
  s.required_ruby_version = Gem::Requirement.new(">= 3.0.0".freeze)
  s.rubygems_version = "3.6.2".freeze
  s.summary = "A redacting Ruby logger to prevent the leaking of secrets via logs".freeze

  s.installed_by_version = "3.6.7".freeze

  s.specification_version = 4

  s.add_runtime_dependency(%q<logger>.freeze, ["~> 1.6".freeze])
end
