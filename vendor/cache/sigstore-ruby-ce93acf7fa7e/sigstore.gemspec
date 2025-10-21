# -*- encoding: utf-8 -*-
# stub: sigstore 0.2.1 ruby lib

Gem::Specification.new do |s|
  s.name = "sigstore".freeze
  s.version = "0.2.1".freeze

  s.required_rubygems_version = Gem::Requirement.new(">= 0".freeze) if s.respond_to? :required_rubygems_version=
  s.metadata = { "allowed_push_host" => "https://rubygems.org", "homepage_uri" => "https://github.com/sigstore/sigstore-ruby", "rubygems_mfa_required" => "true" } if s.respond_to? :metadata=
  s.require_paths = ["lib".freeze]
  s.authors = ["The Sigstore Authors".freeze, "Samuel Giddins".freeze]
  s.bindir = "exe".freeze
  s.date = "1980-01-02"
  s.email = [nil, "segiddins@segiddins.me".freeze]
  s.files = ["CHANGELOG.md".freeze, "CODEOWNERS".freeze, "LICENSE".freeze, "README.md".freeze, "data/_store/prod/root.json".freeze, "data/_store/prod/trusted_root.json".freeze, "data/_store/staging/root.json".freeze, "data/_store/staging/trusted_root.json".freeze, "lib/sigstore.rb".freeze, "lib/sigstore/error.rb".freeze, "lib/sigstore/internal/json.rb".freeze, "lib/sigstore/internal/key.rb".freeze, "lib/sigstore/internal/keyring.rb".freeze, "lib/sigstore/internal/merkle.rb".freeze, "lib/sigstore/internal/set.rb".freeze, "lib/sigstore/internal/util.rb".freeze, "lib/sigstore/internal/x509.rb".freeze, "lib/sigstore/models.rb".freeze, "lib/sigstore/oidc.rb".freeze, "lib/sigstore/policy.rb".freeze, "lib/sigstore/rekor/checkpoint.rb".freeze, "lib/sigstore/rekor/client.rb".freeze, "lib/sigstore/signer.rb".freeze, "lib/sigstore/trusted_root.rb".freeze, "lib/sigstore/tuf.rb".freeze, "lib/sigstore/tuf/config.rb".freeze, "lib/sigstore/tuf/error.rb".freeze, "lib/sigstore/tuf/file.rb".freeze, "lib/sigstore/tuf/keys.rb".freeze, "lib/sigstore/tuf/roles.rb".freeze, "lib/sigstore/tuf/root.rb".freeze, "lib/sigstore/tuf/snapshot.rb".freeze, "lib/sigstore/tuf/targets.rb".freeze, "lib/sigstore/tuf/timestamp.rb".freeze, "lib/sigstore/tuf/trusted_metadata_set.rb".freeze, "lib/sigstore/tuf/updater.rb".freeze, "lib/sigstore/verifier.rb".freeze, "lib/sigstore/version.rb".freeze]
  s.homepage = "https://github.com/sigstore/sigstore-ruby".freeze
  s.licenses = ["Apache-2.0".freeze]
  s.required_ruby_version = Gem::Requirement.new(">= 3.2.0".freeze)
  s.rubygems_version = "3.6.7".freeze
  s.summary = "A pure-ruby implementation of sigstore signature verification".freeze

  s.installed_by_version = "3.6.7".freeze

  s.specification_version = 4

  s.add_runtime_dependency(%q<logger>.freeze, [">= 0".freeze])
  s.add_runtime_dependency(%q<net-http>.freeze, [">= 0".freeze])
  s.add_runtime_dependency(%q<protobug_sigstore_protos>.freeze, ["~> 0.1.0".freeze])
  s.add_runtime_dependency(%q<uri>.freeze, [">= 0".freeze])
end
