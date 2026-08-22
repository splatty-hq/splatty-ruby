require "test_helper"
require "logger"

class ConfigurationTest < Minitest::Test
  include SplattyTestHelpers

  def test_envelope_url_built_from_url
    config = build_configuration(url: "http://host.example:3001", dsn: "abc123")
    assert_equal "abc123", config.dsn_key
    assert_equal "http://host.example:3001/api/envelope", config.envelope_url
  end

  def test_envelope_url_strips_trailing_slash
    config = build_configuration(url: "https://example.com/", dsn: "abc")
    assert_equal "https://example.com/api/envelope", config.envelope_url
  end

  def test_validate_disables_when_url_missing
    config = Splatty::Configuration.new
    config.enabled = true
    config.dsn = "abc"
    config.url = nil
    config.logger = Logger.new(IO::NULL)
    config.validate!
    refute config.enabled?
  end

  def test_validate_disables_when_dsn_missing
    config = Splatty::Configuration.new
    config.enabled = true
    config.url = "https://example.com"
    config.dsn = nil
    config.logger = Logger.new(IO::NULL)
    config.validate!
    refute config.enabled?
  end

  def test_validate_disables_when_url_invalid
    config = Splatty::Configuration.new
    config.enabled = true
    config.dsn = "abc"
    config.url = "not-a-url"
    config.logger = Logger.new(IO::NULL)
    config.validate!
    refute config.enabled?
  end

  def test_disabled_when_dsn_blank
    config = Splatty::Configuration.new
    config.enabled = true
    config.url = "https://example.com"
    config.dsn = ""
    refute config.enabled?
  end

  def test_validate_does_nothing_when_disabled
    config = Splatty::Configuration.new
    config.enabled = false
    config.dsn = nil
    config.url = nil
    config.validate!
  end

  def test_send_default_pii_defaults_to_false
    refute Splatty::Configuration.new.send_default_pii
  end
end
