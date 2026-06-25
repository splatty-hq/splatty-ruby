# Splatty

Ruby client for [Splatty](https://github.com/k0va1/splatty). Captures exceptions
and logs and ships them over the Sentry-compatible envelope protocol.

## Installation

Add to your `Gemfile`:

```ruby
gem "splatty"
```

## Usage

```ruby
Splatty.init do |config|
  config.url         = ENV.fetch("SPLATTY_URL", "https://splatty.k0va1.dev")
  config.dsn         = ENV["SPLATTY_DSN"]
  config.environment = ENV.fetch("RACK_ENV", "development")
  config.release     = ENV["SPLATTY_RELEASE"]
  # config.logs = false  # disable log shipping (default: true)
end

begin
  do_something
rescue => e
  Splatty.capture_exception(e)
end

Splatty.capture_message("hello", level: :info)
```

### Rack

```ruby
use Splatty::Rack
```

### Rails

The Railtie auto-loads when Rails is present. Configure in an initializer:

```ruby
# config/initializers/splatty.rb
Splatty.init do |config|
  config.dsn = ENV["SPLATTY_DSN"]
  # config.url defaults to https://splatty.k0va1.dev — override with ENV["SPLATTY_URL"] if needed
end
```

### Logs

Splatty ships `semantic_logger` as a dependency and auto-registers a Splatty
appender on `Splatty.init`, so any code that logs through `SemanticLogger` is
forwarded to Splatty. In Rails apps, `rails_semantic_logger` is also pulled in
and required by Splatty's railtie, which replaces `Rails.logger` and Rails'
log subscribers with semantic_logger — so request/controller/SQL logs flow to
Splatty with no extra wiring. Disable with `config.logs = false`.

## License

The gem is available as open source under the terms of the
[MIT License](MIT-LICENSE).
