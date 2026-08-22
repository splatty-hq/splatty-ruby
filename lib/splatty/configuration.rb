require "uri"

module Splatty
  class Configuration
    class InvalidDsn < StandardError; end
    class MissingConfig < StandardError; end

    attr_accessor :url, :dsn, :environment, :release, :enabled, :logs,
                  :server_name, :open_timeout, :read_timeout,
                  :logger, :before_send, :send_default_pii

    DEFAULT_URL = "https://splatty.app".freeze

    def initialize
      @enabled = true
      @logs = true
      @url = DEFAULT_URL
      @environment = ENV["RACK_ENV"] || ENV["RAILS_ENV"] || "development"
      @release = ENV["SPLATTY_RELEASE"]
      @server_name = nil
      @open_timeout = 5
      @read_timeout = 10
      @before_send = nil
      @send_default_pii = false
    end

    def validate!
      return unless enabled
      return disable!("config.url is required") if url.to_s.empty?
      return disable!("config.dsn is required") if dsn.to_s.empty?
      begin
        parsed = URI.parse(url)
      rescue URI::InvalidURIError => e
        return disable!("config.url is invalid: #{e.message}")
      end
      return disable!("config.url must include scheme + host") if parsed.host.to_s.empty?
    end

    def disable!(message)
      @enabled = false
      log_warning(message)
      nil
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

    private

    def log_warning(message)
      full = "[Splatty] disabled: #{message}"
      if logger
        logger.warn(full)
      else
        Kernel.warn(full)
      end
    end
  end
end
