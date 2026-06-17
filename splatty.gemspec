Gem::Specification.new do |spec|
  spec.name        = "splatty"
  spec.version     = "0.1.0"
  spec.authors     = ["Alex Koval"]
  spec.summary     = "Sentry-compatible client for Splatty (errors + logs)"
  spec.license     = "MIT"
  spec.required_ruby_version = ">= 3.2"

  spec.files = Dir["lib/**/*.rb"]
  spec.require_paths = ["lib"]

  spec.add_dependency "json", ">= 2.0"
end
