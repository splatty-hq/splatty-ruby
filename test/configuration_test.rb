require "test_helper"

class ConfigurationTest < Minitest::Test
  include SplattyTestHelpers

  def test_parses_dsn_into_base_key_and_project_id
    config = build_configuration(dsn: "http://abc@host.example:3001/7")
    assert_equal "http://host.example:3001", config.parsed_dsn[:base]
    assert_equal "abc", config.dsn_key
    assert_equal "7", config.project_id
    assert_equal "http://host.example:3001/api/7/envelope/", config.envelope_url
  end

  def test_https_default_port_is_omitted_from_base
    config = build_configuration(dsn: "https://abc@example.com/9")
    assert_equal "https://example.com", config.parsed_dsn[:base]
  end

  def test_validate_raises_when_dsn_missing
    config = Splatty::Configuration.new
    config.enabled = true
    config.dsn = nil
    assert_raises(Splatty::Configuration::MissingConfig) { config.validate! }
  end

  def test_validate_raises_on_malformed_dsn
    config = Splatty::Configuration.new
    config.enabled = true
    config.dsn = "not-a-url"
    assert_raises(Splatty::Configuration::InvalidDsn) { config.validate! }
  end

  def test_disabled_when_dsn_blank
    config = Splatty::Configuration.new
    config.enabled = true
    config.dsn = ""
    refute config.enabled?
  end

  def test_validate_does_nothing_when_disabled
    config = Splatty::Configuration.new
    config.enabled = false
    config.dsn = nil
    config.validate!
  end
end
