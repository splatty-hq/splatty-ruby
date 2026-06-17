require "net/http"
require "uri"
require "json"

module Splatty
  class Transport
    SDK_NAME = "splatty.ruby".freeze

    def initialize(configuration)
      @configuration = configuration
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
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = uri.scheme == "https"
      http.open_timeout = @configuration.open_timeout
      http.read_timeout = @configuration.read_timeout

      req = Net::HTTP::Post.new(uri.request_uri, headers)
      req.body = body

      response = http.request(req)
      [response.code.to_i, response.body]
    rescue StandardError => e
      log_failure(uri, e)
      nil
    end

    def log_failure(uri, error)
      logger = @configuration.logger
      msg = "[splatty] transport failure #{uri} #{error.class}: #{error.message}"
      logger ? logger.warn(msg) : warn(msg)
    end
  end
end
