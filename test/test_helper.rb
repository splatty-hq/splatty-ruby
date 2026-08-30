require "minitest/autorun"
require "rack"
require "semantic_logger"
require "splatty"

module SplattyTestHelpers
  def start_splatty(overrides = {})
    Splatty.close
    Splatty.init do |c|
      c.url = overrides.fetch(:url, "http://example.com")
      c.dsn = overrides.fetch(:dsn, "abc")
      c.environment = overrides.fetch(:environment, "test")
      c.release = overrides.fetch(:release, nil)
      c.logs = overrides.fetch(:logs, false)
      c.enabled = overrides.fetch(:enabled, true)
    end
    @transport = Splatty.client.transport
    @transport.define_singleton_method(:send_envelope) do |event|
      (@captured ||= []) << event
    end
  end

  def sent_events
    @transport.instance_variable_get(:@captured) || []
  end

  def build_configuration(overrides = {})
    config = Splatty::Configuration.new
    config.url = overrides[:url] || "http://localhost:3000"
    config.dsn = overrides[:dsn] || "abc123"
    config.environment = overrides[:environment] || "test"
    config.release = overrides[:release] || "0.0.1"
    config.enabled = overrides.fetch(:enabled, true)
    overrides.each { |k, v| config.send("#{k}=", v) if config.respond_to?("#{k}=") }
    config.validate! if config.enabled?
    config
  end
end
