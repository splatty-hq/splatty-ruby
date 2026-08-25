require "test_helper"

class CaptureRailsLogsTest < Minitest::Test
  def setup
    @original = ENV["SPLATTY_RAILS_LOGS"]
    ENV.delete("SPLATTY_RAILS_LOGS")
  end

  def teardown
    ENV["SPLATTY_RAILS_LOGS"] = @original
    ENV.delete("SPLATTY_RAILS_LOGS") if @original.nil?
  end

  def test_left_alone_in_the_environments_a_developer_reads_logs_in
    refute Splatty.capture_rails_logs?("development")
    refute Splatty.capture_rails_logs?("test")
  end

  def test_on_everywhere_else
    assert Splatty.capture_rails_logs?("production")
    assert Splatty.capture_rails_logs?("staging")
  end

  def test_accepts_a_non_string_environment
    refute Splatty.capture_rails_logs?(:development)
    assert Splatty.capture_rails_logs?(:production)
  end

  def test_env_var_forces_it_on
    ENV["SPLATTY_RAILS_LOGS"] = "true"
    assert Splatty.capture_rails_logs?("development")
    ENV["SPLATTY_RAILS_LOGS"] = "1"
    assert Splatty.capture_rails_logs?("test")
  end

  def test_env_var_forces_it_off
    ENV["SPLATTY_RAILS_LOGS"] = "false"
    refute Splatty.capture_rails_logs?("production")
    ENV["SPLATTY_RAILS_LOGS"] = "0"
    refute Splatty.capture_rails_logs?("production")
  end

  def test_unrecognised_env_var_falls_back_to_the_default
    ENV["SPLATTY_RAILS_LOGS"] = "yes"
    refute Splatty.capture_rails_logs?("development")
    assert Splatty.capture_rails_logs?("production")
  end
end
