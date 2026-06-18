require "net/http"
require "uri"
require "json"

module Splatty
  class Transport
    SDK_NAME = "splatty.ruby".freeze
    KEEP_ALIVE_TIMEOUT = 60

    def initialize(configuration)
      @configuration = configuration
      @mutex = Mutex.new
      @connections = {}
    end

    def close_connections
      @mutex.synchronize do
        @connections.each_value { |http| http.finish if http.started? rescue nil }
        @connections.clear
      end
    end

    def send_envelope(event)
      uri = URI.parse(@configuration.envelope_url)
      body = serialize_envelope(event)
      post(uri, body, {
        "Content-Type" => "application/x-sentry-envelope",
        "X-Sentry-Auth" => sentry_auth_header
      })
    end

    def send_logs(host:, logs:)
      return if logs.empty?
      uri = URI.parse(@configuration.logs_url)
      body = JSON.generate({ host: host, logs: logs })
      post(uri, body, {
        "Content-Type" => "application/json",
        "Authorization" => "Bearer #{@configuration.ingest_key}"
      })
    end

    private

    def sentry_auth_header
      "Sentry sentry_version=7, sentry_client=#{SDK_NAME}/#{Splatty::VERSION}, sentry_key=#{@configuration.dsn_key}"
    end

    def serialize_envelope(event)
      header = {
        event_id: event[:event_id],
        sent_at: Time.now.utc.iso8601,
        dsn: @configuration.dsn,
        sdk: { name: SDK_NAME, version: Splatty::VERSION }
      }
      item_payload = JSON.generate(event)
      item_header = {
        type: "event",
        content_type: "application/json",
        length: item_payload.bytesize
      }
      "#{JSON.generate(header)}\n#{JSON.generate(item_header)}\n#{item_payload}"
    end

    def post(uri, body, headers)
      req = Net::HTTP::Post.new(uri.request_uri, headers)
      req.body = body

      key = connection_key(uri)
      @mutex.synchronize do
        http = (@connections[key] ||= start_connection(uri))
        begin
          response = http.request(req)
          [response.code.to_i, response.body]
        rescue StandardError => e
          # Connection may be half-closed by a keep-alive timeout on the server
          # side. Drop it so the next call starts fresh.
          http.finish if http.started? rescue nil
          @connections.delete(key)
          log_failure(uri, e)
          nil
        end
      end
    end

    def connection_key(uri)
      "#{uri.scheme}://#{uri.host}:#{uri.port}"
    end

    def start_connection(uri)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = uri.scheme == "https"
      http.keep_alive_timeout = KEEP_ALIVE_TIMEOUT
      http.open_timeout = @configuration.open_timeout
      http.read_timeout = @configuration.read_timeout
      http.start
      http
    end

    def log_failure(uri, error)
      logger = @configuration.logger
      msg = "[splatty] transport failure #{uri} #{error.class}: #{error.message}"
      logger ? logger.warn(msg) : warn(msg)
    end
  end
end
