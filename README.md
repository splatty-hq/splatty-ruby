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
  config.url         = ENV.fetch("SPLATTY_URL", "https://splatty.app")
  config.dsn         = ENV["SPLATTY_DSN"]
  config.environment = ENV.fetch("RACK_ENV", "development")
  config.release     = ENV["SPLATTY_RELEASE"]
  # config.logs = false  # disable log shipping (default: true)
  # config.send_default_pii = true  # send request headers verbatim (default: false)
end
```

By default (`send_default_pii = false`) sensitive request headers — `Cookie`,
`Authorization`, CSRF tokens, API keys and similar — are replaced with
`[Filtered]` before an event leaves the process. Set `send_default_pii = true`
only if you understand that cookies and auth tokens will then be transmitted and
stored.

```ruby
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
  # config.url defaults to https://splatty.app — override with ENV["SPLATTY_URL"] if needed
end
```

### Background jobs

`Splatty.init` installs error handlers for the job backends it finds loaded, so
failures outside the request cycle are reported too:

- **Active Job** — subscribes to `perform.active_job` and reports any job whose
  exception escaped `retry_on` / `discard_on`. Jobs that are about to be retried
  and jobs discarded on purpose are not reported. Events are tagged with
  `job_class`, `job_queue` and `job_backend` (the queue adapter name), and carry
  the job id, attempt count and serialized arguments as extra data.
- **Sidekiq** — appends an error handler to `Sidekiq.configure_server`, which
  also covers failures Active Job never sees: plain `Sidekiq::Job` classes,
  unparseable payloads and errors raised while dispatching a job.
- **Solid Queue** — chains onto `SolidQueue.on_thread_error` (any previously
  configured handler still runs), catching worker, dispatcher and supervisor
  thread errors on top of the job failures Active Job reports.

An exception object is only reported once, so a job failure that surfaces
through two of these paths produces a single event.

### Logs

Splatty ships `semantic_logger` as a dependency and auto-registers a Splatty
appender on `Splatty.init`, so any code that logs through `SemanticLogger` is
forwarded to Splatty. Disable with `config.logs = false`.

In Rails apps, `rails_semantic_logger` is also pulled in and required by
Splatty's railtie, which replaces `Rails.logger` and Rails' log subscribers with
semantic_logger — so request/controller/SQL logs flow to Splatty with no extra
wiring.

That replacement happens as the gem is required, which is far earlier than
`Splatty.init` and applies to whatever environment the app is booting. Since it
changes what a developer sees in the terminal, and neither environment ships
anything anyway, **`development` and `test` keep the stock Rails logger**;
everything else gets semantic logging. Override either way with
`SPLATTY_RAILS_LOGS` (`true`/`1` or `false`/`0`):

```sh
SPLATTY_RAILS_LOGS=true bin/rails server   # semantic logging in development too
```

Note this is separate from `config.logs`, which decides whether captured logs
are *shipped*. Turning `config.logs` off in production still leaves Rails.logger
replaced; set `SPLATTY_RAILS_LOGS=false` to leave the logger alone as well.

## License

The gem is available as open source under the terms of the
[MIT License](MIT-LICENSE).
