require "uri"

module Splatty
  class Configuration
    class InvalidDsn < StandardError; end
    class MissingConfig < StandardError; end

    attr_accessor :dsn, :environment, :release, :enabled,
                  :server_name, :open_timeout, :read_timeout,
                  :logger, :before_send

    def initialize
      @enabled = true
      @environment = ENV["RACK_ENV"] || ENV["RAILS_ENV"] || "development"
      @release = ENV["SPLATTY_RELEASE"]
      @server_name = nil
      @open_timeout = 5
      @read_timeout = 10
      @before_send = nil
    end

    def validate!
      return unless enabled
      raise MissingConfig, "config.dsn is required" if dsn.to_s.empty?
      parsed_dsn
    end

    def enabled?
      !!@enabled && !dsn.to_s.empty?
    end

    def parsed_dsn
      @parsed_dsn ||= parse_dsn(dsn)
    end

    def envelope_url
      "#{parsed_dsn[:base]}/api/#{parsed_dsn[:project_id]}/envelope/"
    end

    def dsn_key
      parsed_dsn[:key]
    end

    def project_id
      parsed_dsn[:project_id]
    end

    private

    def parse_dsn(raw)
      uri = URI.parse(raw)
      raise InvalidDsn, "DSN must include scheme + host" if uri.host.nil? || uri.scheme.nil?
      path = uri.path.to_s.sub(%r{\A/}, "")
      raise InvalidDsn, "DSN must end with /<project_id>" if path.empty?
      port_part = uri.port && uri.port != uri.default_port ? ":#{uri.port}" : ""
      {
        base: "#{uri.scheme}://#{uri.host}#{port_part}",
        key: uri.user.to_s,
        project_id: path
      }
    rescue URI::InvalidURIError => e
      raise InvalidDsn, e.message
    end
  end
end
