require "test_helper"

class EventTest < Minitest::Test
  include SplattyTestHelpers

  def setup
    @config = build_configuration
  end

  def raise_and_capture
    raise "boom"
  rescue RuntimeError => e
    return e
  end

  def test_from_exception_builds_envelope_payload
    error = raise_and_capture
    event = Splatty::Event.from_exception(error, @config)

    assert_match(/\A[a-f0-9]{32}\z/, event[:event_id])
    assert_equal "ruby", event[:platform]
    assert_equal "test", event[:environment]
    assert_equal "0.0.1", event[:release]
    assert_equal "error", event[:level]
    assert_equal 1, event[:exception][:values].size

    value = event[:exception][:values].first
    assert_equal "RuntimeError", value[:type]
    assert_equal "boom", value[:value]
    assert value[:stacktrace][:frames].any? { |f| f[:lineno].is_a?(Integer) }
  end

  def test_frames_include_source_context
    error = raise_and_capture
    event = Splatty::Event.from_exception(error, @config)
    frame = event[:exception][:values].first[:stacktrace][:frames].last

    assert_equal __FILE__, frame[:abs_path]
    assert_equal 'raise "boom"', frame[:context_line].strip
    assert_equal 5, frame[:pre_context].size
    assert_equal 5, frame[:post_context].size
    assert_includes frame[:pre_context].last, "def raise_and_capture"
  end

  def test_context_lines_zero_disables_source_context
    error = raise_and_capture
    event = Splatty::Event.from_exception(error, build_configuration(context_lines: 0))
    frame = event[:exception][:values].first[:stacktrace][:frames].last

    assert_equal __FILE__, frame[:abs_path]
    refute frame.key?(:context_line)
  end

  def test_from_exception_unwraps_cause_chain
    error = begin
      begin
        raise "inner"
      rescue
        raise StandardError, "outer"
      end
    rescue => e
      e
    end

    event = Splatty::Event.from_exception(error, @config)
    types = event[:exception][:values].map { |v| v[:type] }
    assert_equal %w[RuntimeError StandardError], types
  end

  def test_from_message_uses_level_and_message_shape
    event = Splatty::Event.from_message("hello", @config, level: :warn, scope: { tags: { region: "us" } })
    assert_equal "warn", event[:level]
    assert_equal "hello", event[:message][:formatted]
    assert_equal({ region: "us" }, event[:tags])
  end

  def test_scope_request_passed_through
    event = Splatty::Event.from_message("x", @config, scope: { request: { url: "/x", method: "GET" } })
    assert_equal "/x", event[:request][:url]
  end
end
