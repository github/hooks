# -*- encoding: utf-8 -*-
# stub: sigstore-cli 0.2.1 ruby lib

Gem::Specification.new do |s|
  s.name = "sigstore-cli".freeze
  s.version = "0.2.1".freeze

  s.required_rubygems_version = Gem::Requirement.new(">= 0".freeze) if s.respond_to? :required_rubygems_version=
  s.metadata = { "allowed_push_host" => "https://rubygems.org", "homepage_uri" => "https://github.com/sigstore/sigstore-ruby", "rubygems_mfa_required" => "true" } if s.respond_to? :metadata=
  s.require_paths = ["lib".freeze]
  s.authors = ["The Sigstore Authors".freeze, "Samuel Giddins".freeze]
  s.bindir = "exe".freeze
  s.date = "1980-01-02"
  s.email = [nil, "segiddins@segiddins.me".freeze]
  s.executables = ["sigstore-cli".freeze]
  s.files = ["exe/sigstore-cli".freeze, "lib/sigstore/cli.rb".freeze, "lib/sigstore/cli/id_token.rb".freeze]
  s.homepage = "https://github.com/sigstore/sigstore-ruby".freeze
  s.licenses = ["Apache-2.0".freeze]
  s.required_ruby_version = Gem::Requirement.new(">= 3.2.0".freeze)
  s.rubygems_version = "3.6.7".freeze
  s.summary = "A CLI interface to the sigstore ruby client".freeze

  s.installed_by_version = "3.6.7".freeze

  s.specification_version = 4

  s.add_runtime_dependency(%q<sigstore>.freeze, ["= 0.2.1".freeze])
  s.add_runtime_dependency(%q<thor>.freeze, [">= 0".freeze])
end
