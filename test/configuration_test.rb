require "test_helper"

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

  def test_validate_raises_when_url_missing
    config = Splatty::Configuration.new
    config.enabled = true
    config.dsn = "abc"
    config.url = nil
    assert_raises(Splatty::Configuration::MissingConfig) { config.validate! }
  end

  def test_validate_raises_when_dsn_missing
    config = Splatty::Configuration.new
    config.enabled = true
    config.url = "https://example.com"
    config.dsn = nil
    assert_raises(Splatty::Configuration::MissingConfig) { config.validate! }
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
end
