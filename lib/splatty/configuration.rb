require "uri"

module Splatty
  class Configuration
    class InvalidDsn < StandardError; end
    class MissingConfig < StandardError; end

    attr_accessor :url, :dsn, :environment, :release, :enabled,
                  :server_name, :open_timeout, :read_timeout,
                  :logger, :before_send

    DEFAULT_URL = "https://splatty.k0va1.dev".freeze

    def initialize
      @enabled = true
      @url = DEFAULT_URL
      @environment = ENV["RACK_ENV"] || ENV["RAILS_ENV"] || "development"
      @release = ENV["SPLATTY_RELEASE"]
      @server_name = nil
      @open_timeout = 5
      @read_timeout = 10
      @before_send = nil
    end

    def validate!
      return unless enabled
      raise MissingConfig, "config.url is required" if url.to_s.empty?
      raise MissingConfig, "config.dsn is required" if dsn.to_s.empty?
      raise InvalidDsn, "config.url must include scheme + host" if URI.parse(url).host.to_s.empty?
    rescue URI::InvalidURIError => e
      raise InvalidDsn, e.message
    end

    def enabled?
      !!@enabled && !dsn.to_s.empty? && !url.to_s.empty?
    end

    def envelope_url
      "#{url.to_s.sub(%r{/+\z}, "")}/api/envelope"
    end

    def dsn_key
      dsn
    end
  end
end
