# Changelog

## [0.2.0](https://github.com/splatty-hq/splatty-ruby/compare/v0.1.1...v0.2.0) (2026-08-25)


### ⚠ BREAKING CHANGES

* `development` and `test` no longer get semantic logging. Set `SPLATTY_RAILS_LOGS=true` to restore it there.

### Features

* leave Rails' logger alone in development and test

## [0.1.1](https://github.com/splatty-hq/splatty-ruby/compare/v0.1.0...v0.1.1) (2026-08-24)


### Features

* auto-install log appender and rails_semantic_logger ([5c7f047](https://github.com/splatty-hq/splatty-ruby/commit/5c7f0474a1a7c095b9a14e0b4795a41c2fa072f7))
* default the server URL to https://splatty.app ([1f7e916](https://github.com/splatty-hq/splatty-ruby/commit/1f7e916fa75180781fd037343851c4af221ec427))
* initial splatty-ruby sdk (config, transport, event, rack, semantic_logger) ([3d944e1](https://github.com/splatty-hq/splatty-ruby/commit/3d944e117674d430b12bbe1dcc12e072fdc214cf))
* inline SQL into the log message ([1c2a9a6](https://github.com/splatty-hq/splatty-ruby/commit/1c2a9a650a03fdf59a53b7149e392785c4eacf2f))
* **jobs:** report background job failures ([d8eda84](https://github.com/splatty-hq/splatty-ruby/commit/d8eda84dc17778e71a137f13c0eff0c143094507))
* **rack:** tag captured exceptions with the request id ([5465c89](https://github.com/splatty-hq/splatty-ruby/commit/5465c89077cf0fc868ad7461e2cb4ad0ea14f5eb))
* scrub sensitive request headers unless send_default_pii is enabled ([2f7c63d](https://github.com/splatty-hq/splatty-ruby/commit/2f7c63d10370d2a7fcc58a9e0ce5fcc9358b7e3d))
* ship logs as a 'log' envelope item via the existing envelope endpoint ([d48576e](https://github.com/splatty-hq/splatty-ruby/commit/d48576e54307856fef0918599da546c9d4d0ab95))


### Bug Fixes

* inherit global SemanticLogger level in the appender ([9358d23](https://github.com/splatty-hq/splatty-ruby/commit/9358d23c4546e6536d717104698a9bb4e2cb49e2))
* SDK drops log entries for splatty intake paths to break dogfood loop ([2602984](https://github.com/splatty-hq/splatty-ruby/commit/260298452fa2647f0a11fd178897c867170643f6))
* warn and disable on missing or invalid config instead of raising ([6365af5](https://github.com/splatty-hq/splatty-ruby/commit/6365af5a5d378b953c1f797c926825286a4668c1))


### Performance Improvements

* default SDK log flush interval to 15s ([73ebdc6](https://github.com/splatty-hq/splatty-ruby/commit/73ebdc6d5edaeb253c581a6e0c254299cc8a6756))
* gzip outbound transport bodies ([1e199c2](https://github.com/splatty-hq/splatty-ruby/commit/1e199c2950bb8308ea1b472bea7a7a8760dc6bea))
* reuse net::http connections in transport (keep-alive) ([8921738](https://github.com/splatty-hq/splatty-ruby/commit/892173809f13cdd9a53212c7a1bb8a6b22a8b9fc))

## Changelog
