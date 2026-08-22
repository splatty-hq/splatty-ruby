require "test_helper"

module Sidekiq
  class Config
    def error_handlers
      @error_handlers ||= []
    end

    def handle_exception(exception, context = {})
      error_handlers.each { |handler| handler.call(exception, context, self) }
    end
  end

  class << self
    def default_configuration
      @default_configuration ||= Config.new
    end

    def configure_server
      yield default_configuration
    end
  end
end

class SidekiqIntegrationTest < Minitest::Test
  include SplattyTestHelpers

  JOB = {
    "class" => "Alerts::EvaluateThresholdsJob",
    "args" => [],
    "queue" => "default",
    "jid" => "558644111a4ebf3fa967cdd0",
    "retry_count" => 7
  }.freeze

  def setup
    start_splatty
  end

  def teardown
    Splatty.close
  end

  def config
    ::Sidekiq.default_configuration
  end

  def raised(message = "boom")
    raise NoMethodError, message
  rescue NoMethodError => e
    e
  end

  def test_registers_an_error_handler_on_the_server
    assert_equal 1, config.error_handlers.count { |h| h.is_a?(Splatty::Sidekiq::ErrorHandler) }
  end

  def test_removes_the_handler_on_close
    Splatty.close

    assert_empty config.error_handlers.select { |h| h.is_a?(Splatty::Sidekiq::ErrorHandler) }
  end

  def test_does_not_register_twice
    Splatty::Sidekiq.install!

    assert_equal 1, config.error_handlers.count { |h| h.is_a?(Splatty::Sidekiq::ErrorHandler) }
  end

  def test_captures_a_job_failure_with_its_context
    config.handle_exception(raised, { context: "Job raised exception", job: JOB })

    assert_equal 1, sent_events.size
    event = sent_events.first
    assert_equal "NoMethodError", event[:exception][:values].first[:type]
    assert_equal "sidekiq", event[:tags]["job_backend"]
    assert_equal "Alerts::EvaluateThresholdsJob", event[:tags]["job_class"]
    assert_equal "default", event[:tags]["job_queue"]
    assert_equal "Alerts::EvaluateThresholdsJob", event[:transaction]
    assert_equal "558644111a4ebf3fa967cdd0", event[:extra]["job_id"]
    assert_equal 7, event[:extra]["job_retry_count"]
    assert_equal "Job raised exception", event[:extra]["sidekiq_context"]
    assert_equal "[]", event[:extra]["job_args"]
  end

  def test_prefers_the_wrapped_active_job_class
    job = { "class" => "Sidekiq::ActiveJob::Wrapper", "wrapped" => "Billing::UsageSweepJob", "queue" => "low" }
    config.handle_exception(raised, { context: "Job raised exception", job: job })

    assert_equal "Billing::UsageSweepJob", sent_events.first[:tags]["job_class"]
    assert_equal "Billing::UsageSweepJob", sent_events.first[:transaction]
  end

  def test_captures_failures_that_carry_no_job
    config.handle_exception(raised, { context: "Invalid JSON for job", jobstr: "{oops" })

    assert_equal 1, sent_events.size
    event = sent_events.first
    assert_equal "sidekiq", event[:tags]["job_backend"]
    refute event[:tags].key?("job_class")
    refute event.key?(:transaction)
    assert_equal "Invalid JSON for job", event[:extra]["sidekiq_context"]
  end

  def test_truncates_oversized_args
    job = JOB.merge("args" => [ "x" * 4000 ])
    config.handle_exception(raised, { job: job })

    args = sent_events.first[:extra]["job_args"]
    assert_equal Splatty::Jobs::MAX_ARGS_LENGTH + "...(truncated)".length, args.length
  end

  def test_reports_an_exception_only_once
    exception = raised
    config.handle_exception(exception, { job: JOB })
    config.handle_exception(exception, { job: JOB })

    assert_equal 1, sent_events.size
  end

  def test_does_nothing_once_closed
    Splatty.close
    config.handle_exception(raised, { job: JOB })

    assert_empty sent_events
  end
end
