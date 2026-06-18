require "test_helper"
require "webrick"

class TransportTest < Minitest::Test
  include SplattyTestHelpers

  def setup
    @requests = []
    @server = WEBrick::HTTPServer.new(
      Port: 0,
      Logger: WEBrick::Log.new(File::NULL),
      AccessLog: []
    )
    @server.mount_proc("/") do |req, res|
      @requests << {
        path: req.path,
        method: req.request_method,
        body: req.body,
        headers: req.header
      }
      res.status = 202
      res.body = ""
    end
    @thread = Thread.new { @server.start }
    @port = @server[:Port]
  end

  def teardown
    @server.shutdown
    @thread.join(2)
  end

  def config
    @config ||= build_configuration(dsn: "http://abc@127.0.0.1:#{@port}/42")
  end

  def test_send_envelope_posts_three_line_body
    transport = Splatty::Transport.new(config)
    event = { event_id: "deadbeef" * 4, exception: { values: [] } }
    transport.send_envelope(event)

    req = @requests.first
    assert_equal "/api/42/envelope/", req[:path]
    assert_equal "POST", req[:method]
    assert_includes req[:headers]["x-sentry-auth"].first, "sentry_key=abc"
    assert_equal "application/x-sentry-envelope", req[:headers]["content-type"].first
    assert_equal "gzip", req[:headers]["content-encoding"].first

    decoded = Zlib::GzipReader.new(StringIO.new(req[:body])).read
    lines = decoded.split("\n")
    assert_equal 3, lines.size
    envelope_header = JSON.parse(lines[0])
    item_header = JSON.parse(lines[1])
    payload = JSON.parse(lines[2])

    assert_equal "deadbeef" * 4, envelope_header["event_id"]
    assert_equal "splatty.ruby", envelope_header["sdk"]["name"]
    assert_equal "event", item_header["type"]
    assert_equal payload.to_json.bytesize, item_header["length"]
  end

  def test_send_logs_posts_envelope_with_log_item
    transport = Splatty::Transport.new(config)
    logs = [{ level: "info", message: "hello" }]
    transport.send_logs(host: "test-host", logs: logs)

    req = @requests.first
    assert_equal "/api/42/envelope/", req[:path]
    assert_includes req[:headers]["x-sentry-auth"].first, "sentry_key=abc"
    assert_equal "application/x-sentry-envelope", req[:headers]["content-type"].first
    assert_equal "gzip", req[:headers]["content-encoding"].first

    decoded = Zlib::GzipReader.new(StringIO.new(req[:body])).read
    lines = decoded.split("\n")
    assert_equal 3, lines.size
    item_header = JSON.parse(lines[1])
    payload = JSON.parse(lines[2])
    assert_equal "log", item_header["type"]
    assert_equal 1, item_header["item_count"]
    assert_equal "test-host", payload["host"]
    assert_equal 1, payload["items"].size
    assert_equal "hello", payload["items"].first["message"]
  end

  def test_send_logs_skips_when_empty
    transport = Splatty::Transport.new(config)
    transport.send_logs(host: "h", logs: [])
    assert_empty @requests
  end
end
