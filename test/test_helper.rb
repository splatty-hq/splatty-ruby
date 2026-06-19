require "minitest/autorun"
require "rack"
require "semantic_logger"
require "splatty"

module SplattyTestHelpers
  def build_configuration(overrides = {})
    config = Splatty::Configuration.new
    config.dsn = overrides[:dsn] || "http://abc123@localhost:3000/42"
    config.environment = overrides[:environment] || "test"
    config.release = overrides[:release] || "0.0.1"
    config.enabled = overrides.fetch(:enabled, true)
    overrides.each { |k, v| config.send("#{k}=", v) if config.respond_to?("#{k}=") }
    config.validate! if config.enabled?
    config
  end
end
