require "test_helper"

class RackMiddlewareTest < Minitest::Test
  include SplattyTestHelpers

  def setup
    Splatty.close
    Splatty.init do |c|
      c.url = "http://example.com"
      c.dsn = "abc"
      c.environment = "test"
      c.enabled = true
    end
    @transport = Splatty.client.transport
    @transport.define_singleton_method(:send_envelope) do |event|
      (@captured ||= []) << event
    end
  end

  def teardown
    Splatty.close
  end

  def sent_events
    @transport.instance_variable_get(:@captured) || []
  end

  def test_passes_through_on_success
    app = ->(_env) { [200, {}, ["ok"]] }
    middleware = Splatty::Rack::CaptureExceptions.new(app)
    status, _, _ = middleware.call(Rack::MockRequest.env_for("/x"))
    assert_equal 200, status
    assert_empty sent_events
  end

  def test_captures_and_reraises_on_exception
    app = ->(_env) { raise "boom" }
    middleware = Splatty::Rack::CaptureExceptions.new(app)
    err = assert_raises(RuntimeError) do
      middleware.call(Rack::MockRequest.env_for("/x?y=1", method: "POST"))
    end
    assert_equal "boom", err.message
    assert_equal 1, sent_events.size
    event = sent_events.first
    assert_equal "RuntimeError", event[:exception][:values].first[:type]
    assert_equal "POST", event[:request][:method]
    assert_includes event[:request][:url], "/x?y=1"
  end

  def test_tags_events_with_the_request_id
    app = ->(_env) { raise "boom" }
    middleware = Splatty::Rack::CaptureExceptions.new(app)
    env = Rack::MockRequest.env_for("/x")
    env["action_dispatch.request_id"] = "req-abc-123"
    assert_raises(RuntimeError) { middleware.call(env) }
    assert_equal "req-abc-123", sent_events.first[:tags]["request_id"]
  end

  def test_falls_back_to_the_x_request_id_header
    app = ->(_env) { raise "boom" }
    middleware = Splatty::Rack::CaptureExceptions.new(app)
    env = Rack::MockRequest.env_for("/x", "HTTP_X_REQUEST_ID" => "hdr-456")
    assert_raises(RuntimeError) { middleware.call(env) }
    assert_equal "hdr-456", sent_events.first[:tags]["request_id"]
  end

  def test_omits_the_tag_without_a_request_id
    app = ->(_env) { raise "boom" }
    middleware = Splatty::Rack::CaptureExceptions.new(app)
    assert_raises(RuntimeError) { middleware.call(Rack::MockRequest.env_for("/x")) }
    assert_equal({}, sent_events.first[:tags])
  end
end
