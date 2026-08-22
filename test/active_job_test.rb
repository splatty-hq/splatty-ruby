require "test_helper"
require "active_job"
require "active_support/core_ext/numeric/time"
require "logger"

class ActiveJobIntegrationTest < Minitest::Test
  include SplattyTestHelpers

  class BoomJob < ::ActiveJob::Base
    queue_as :critical

    def perform(*)
      raise ArgumentError, "boom"
    end
  end

  class DiscardedJob < ::ActiveJob::Base
    discard_on ArgumentError

    def perform(*)
      raise ArgumentError, "discarded"
    end
  end

  class RetriedJob < ::ActiveJob::Base
    retry_on ArgumentError, attempts: 3, wait: 1.second

    def perform(*)
      raise ArgumentError, "will retry"
    end
  end

  class ExhaustedJob < ::ActiveJob::Base
    retry_on ArgumentError, attempts: 1, wait: 1.second

    def perform(*)
      raise ArgumentError, "no retries left"
    end
  end

  def setup
    ::ActiveJob::Base.queue_adapter = :test
    ::ActiveJob::Base.logger = ::Logger.new(IO::NULL)
    start_splatty
  end

  def teardown
    Splatty.close
  end

  def test_captures_a_failing_job_with_its_context
    assert_raises(ArgumentError) { BoomJob.perform_now(1, "two") }

    assert_equal 1, sent_events.size
    event = sent_events.first
    assert_equal "ArgumentError", event[:exception][:values].first[:type]
    assert_equal "test", event[:tags]["job_backend"]
    assert_equal "ActiveJobIntegrationTest::BoomJob", event[:tags]["job_class"]
    assert_equal "critical", event[:tags]["job_queue"]
    assert_equal "ActiveJobIntegrationTest::BoomJob", event[:transaction]
    assert_equal "[1,\"two\"]", event[:extra]["job_args"]
    assert_equal 1, event[:extra]["job_executions"]
    refute_nil event[:extra]["job_id"]
  end

  def test_ignores_a_discarded_job
    DiscardedJob.perform_now

    assert_empty sent_events
  end

  def test_ignores_a_failure_that_will_be_retried
    RetriedJob.perform_now

    assert_empty sent_events
  end

  def test_captures_once_the_retries_are_exhausted
    assert_raises(ArgumentError) { ExhaustedJob.perform_now }

    assert_equal 1, sent_events.size
    assert_equal "ActiveJobIntegrationTest::ExhaustedJob", sent_events.first[:tags]["job_class"]
  end

  def test_stops_capturing_once_closed
    Splatty.close
    assert_raises(ArgumentError) { BoomJob.perform_now }

    assert_empty sent_events
  end
end
