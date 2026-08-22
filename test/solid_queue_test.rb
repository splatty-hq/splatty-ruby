require "test_helper"

module SolidQueue
  class << self
    attr_accessor :on_thread_error
  end
end

class SolidQueueIntegrationTest < Minitest::Test
  include SplattyTestHelpers

  class PollingError < StandardError; end

  def setup
    @forwarded = []
    ::SolidQueue.on_thread_error = ->(exception) { @forwarded << exception }
    start_splatty
  end

  def teardown
    Splatty.close
    ::SolidQueue.on_thread_error = nil
  end

  def raised(message = "boom")
    raise PollingError, message
  rescue PollingError => e
    e
  end

  def test_captures_thread_errors
    ::SolidQueue.on_thread_error.call(raised)

    assert_equal 1, sent_events.size
    event = sent_events.first
    assert_equal "SolidQueueIntegrationTest::PollingError", event[:exception][:values].first[:type]
    assert_equal "solid_queue", event[:tags]["job_backend"]
  end

  def test_keeps_calling_the_previous_handler
    exception = raised
    ::SolidQueue.on_thread_error.call(exception)

    assert_equal [ exception ], @forwarded
  end

  def test_tags_the_reporting_thread
    thread = Thread.new do
      Thread.current.name = "Worker(0.1)"
      ::SolidQueue.on_thread_error.call(raised)
    end
    thread.join

    assert_equal "Worker(0.1)", sent_events.first[:extra]["thread"]
  end

  def test_restores_the_previous_handler_on_close
    Splatty.close
    exception = raised
    ::SolidQueue.on_thread_error.call(exception)

    assert_equal [ exception ], @forwarded
    assert_empty sent_events
  end

  def test_does_not_double_report_a_job_failure_already_captured
    exception = raised
    Splatty.capture_exception(exception, tags: { "job_backend" => "solid_queue" })
    ::SolidQueue.on_thread_error.call(exception)

    assert_equal 1, sent_events.size
  end
end
