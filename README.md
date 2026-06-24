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

### Semantic Logger

```ruby
SemanticLogger.add_appender(appender: Splatty::SemanticLogger.new)
```

## License

The gem is available as open source under the terms of the
[MIT License](MIT-LICENSE).
