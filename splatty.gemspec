require_relative "lib/splatty/version"

Gem::Specification.new do |spec|
  spec.name = "splatty"
  spec.version = Splatty::VERSION
  spec.authors = ["Alex Koval"]
  spec.email = ["al3xander.koval@gmail.com"]
  spec.homepage = "https://github.com/k0va1/splatty-ruby"
  spec.summary = "Sentry-compatible client for Splatty (errors + logs)"
  spec.description = "Ruby client for Splatty. Captures exceptions and logs and ships them over the Sentry-compatible envelope protocol."
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.2"

  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = "#{spec.homepage}/blob/master/CHANGELOG.md"
  spec.metadata["rubygems_mfa_required"] = "true"

  spec.files = Dir["lib/**/*.rb", "MIT-LICENSE", "README.md", "CHANGELOG.md"]
  spec.require_paths = ["lib"]

  spec.add_dependency "json", "~> 2.0"
end
