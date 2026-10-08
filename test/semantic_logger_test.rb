require "test_helper"

class SemanticLoggerAppenderTest < Minitest::Test
  include SplattyTestHelpers

  def setup
    Splatty.close
    Splatty.init do |c|
      c.url = "http://example.com"
      c.dsn = "abc"
      c.environment = "test"
      c.release = "rel-9"
    end
    @transport = Splatty.client.instance_variable_get(:@transport)
    @transport.define_singleton_method(:send_logs) do |**args|
      (@recorded ||= []) << args
    end
  end

  def teardown
    Splatty.close
  end

  def recorded
    @transport.instance_variable_get(:@recorded) || []
  end

  def test_enqueues_and_dispatches_log_entries
    appender = Splatty::SemanticLogger::Appender.new(
      level: :info,
      batch_size: 10,
      flush_interval: 0.05,
      host: "h-1"
    )

    log = ::SemanticLogger::Log.new("Test", :info)
    log.message = "hi"
    log.time = Time.utc(2026, 6, 17, 12, 0, 0)
    log.named_tags = { request_id: "rid", method: "GET", path: "/x", status: 200, duration_ms: 1.5 }
    log.payload = { user: "u" }
    appender.log(log)

    appender.close

    assert_equal 1, recorded.size
    batch = recorded.first
    assert_equal "h-1", batch[:host]
    entry = batch[:logs].first
    assert_equal "hi", entry[:message]
    assert_equal "info", entry[:level]
    assert_equal "rid", entry[:request_id]
    assert_equal "GET", entry[:method]
    assert_equal "/x", entry[:path]
    assert_equal 200, entry[:status]
    assert_in_delta 1.5, entry[:duration_ms]
    assert_equal "rel-9", entry[:release]
    assert_includes entry[:fields].keys, "user"
  end

  def test_skips_when_splatty_disabled
    Splatty.close
    appender = Splatty::SemanticLogger::Appender.new(flush_interval: 0.05)
    log = ::SemanticLogger::Log.new("Test", :info)
    log.message = "hi"
    refute appender.log(log)
    appender.close
  end

  def test_drops_logs_about_splatty_intake_paths
    appender = Splatty::SemanticLogger::Appender.new(flush_interval: 5, host: "h")

    %w[/api/4/logs /api/42/metrics /api/1/envelope/ /api/envelope /api/metrics /api/logs /api/envelope/].each do |path|
      log = ::SemanticLogger::Log.new("Test", :info)
      log.message = "Completed POST #{path}"
      log.named_tags = { path: path, method: "POST", status: 202 }
      refute appender.log(log), "expected #{path} to be dropped"
    end

    %w[/users/42 /api/envelopes].each do |path|
      log = ::SemanticLogger::Log.new("Test", :info)
      log.message = "real customer request"
      log.named_tags = { path: path, method: "GET", status: 200 }
      assert appender.log(log), "expected #{path} to be kept"
    end

    appender.close
    assert_equal %w[/users/42 /api/envelopes], recorded.first[:logs].map { |entry| entry[:path] }
  end

  def test_flushes_early_when_batch_size_reached
    appender = Splatty::SemanticLogger::Appender.new(
      level: :info, batch_size: 2, flush_interval: 60, host: "h"
    )

    2.times do |i|
      log = ::SemanticLogger::Log.new("Test", :info)
      log.message = "m#{i}"
      appender.log(log)
    end

    deadline = Time.now + 2
    sleep 0.01 while recorded.empty? && Time.now < deadline
    assert_equal 1, recorded.size
    assert_equal 2, recorded.first[:logs].size
  ensure
    appender.close
  end
end
