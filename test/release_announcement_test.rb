require "test_helper"
require "webrick"

class ReleaseAnnouncementTest < Minitest::Test
  include SplattyTestHelpers

  def setup
    @requests = []
    @server = WEBrick::HTTPServer.new(Port: 0, Logger: WEBrick::Log.new(File::NULL), AccessLog: [])
    @server.mount_proc("/") do |req, res|
      @requests << { path: req.path, body: req.body, headers: req.header }
      res.status = 202
      res.body = ""
    end
    @thread = Thread.new { @server.start }
    @port = @server[:Port]
  end

  def teardown
    Splatty.close
    @server.shutdown
    @thread.join(2)
  end

  def url
    "http://127.0.0.1:#{@port}"
  end

  def decoded_item(request)
    lines = Zlib::GzipReader.new(StringIO.new(request[:body])).read.split("\n")
    [ JSON.parse(lines[1]), JSON.parse(lines[2]) ]
  end

  def test_send_release_posts_a_release_envelope_item
    transport = Splatty::Transport.new(build_configuration(url: url, dsn: "abc"))
    transport.send_release(release: "sha-abc123", environment: "production")

    request = @requests.first
    assert_equal "/api/envelope", request[:path]
    assert_equal "Bearer abc", request[:headers]["authorization"].first
    assert_equal "application/x-splatty-envelope", request[:headers]["content-type"].first

    item_header, payload = decoded_item(request)
    assert_equal "release", item_header["type"]
    assert_equal payload.to_json.bytesize, item_header["length"]
    assert_equal "sha-abc123", payload["release"]
    assert_equal "production", payload["environment"]
  end

  def test_init_announces_the_configured_release
    Splatty.close
    Splatty.init do |c|
      c.url = url
      c.dsn = "abc"
      c.environment = "production"
      c.release = "sha-abc123"
      c.logs = false
    end
    Splatty.close

    assert_equal 1, @requests.size
    _, payload = decoded_item(@requests.first)
    assert_equal "sha-abc123", payload["release"]
    assert_equal "production", payload["environment"]
  end

  def test_init_says_nothing_without_a_release
    start_splatty(url: url)
    Splatty.close

    assert_empty @requests
  end

  def test_init_says_nothing_while_disabled
    Splatty.close
    Splatty.init do |c|
      c.url = url
      c.dsn = "abc"
      c.release = "sha-abc123"
      c.enabled = false
      c.logs = false
    end
    Splatty.close

    assert_empty @requests
  end

  def test_a_process_announces_its_release_only_once
    Splatty.close
    Splatty.init do |c|
      c.url = url
      c.dsn = "abc"
      c.release = "sha-abc123"
      c.logs = false
    end
    Splatty.announce_release
    Splatty.announce_release
    Splatty.close

    assert_equal 1, @requests.size
  end

  def test_an_unreachable_server_does_not_take_the_boot_down
    Splatty.close
    Splatty.init do |c|
      c.url = "http://127.0.0.1:1"
      c.dsn = "abc"
      c.release = "sha-abc123"
      c.logs = false
      c.open_timeout = 1
      c.read_timeout = 1
      c.logger = Logger.new(File::NULL)
    end

    Splatty.close
    assert_empty @requests
  end
end
