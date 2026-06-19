require "test_helper"

class RackMiddlewareTest < Minitest::Test
  include SplattyTestHelpers

  def setup
    Splatty.close
    Splatty.init do |c|
      c.dsn = "http://abc@example.com/1"
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
end
