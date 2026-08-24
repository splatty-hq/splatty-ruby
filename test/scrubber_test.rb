require "test_helper"

class ScrubberTest < Minitest::Test
  include SplattyTestHelpers

  def scrub(event, **overrides)
    config = build_configuration(overrides)
    Splatty::Scrubber.new(config).scrub(event)
  end

  def event_with_headers(headers)
    { request: { url: "http://example.com/y", method: "GET", headers: headers } }
  end

  def test_filters_sensitive_headers_by_default
    event = scrub(event_with_headers(
      "Cookie" => "session=abc",
      "Authorization" => "Bearer secret",
      "X-Csrf-Token" => "tok",
      "X-Api-Key" => "k",
      "Accept" => "text/html",
      "User-Agent" => "curl"
    ))

    headers = event[:request][:headers]
    assert_equal "[Filtered]", headers["Cookie"]
    assert_equal "[Filtered]", headers["Authorization"]
    assert_equal "[Filtered]", headers["X-Csrf-Token"]
    assert_equal "[Filtered]", headers["X-Api-Key"]
    assert_equal "text/html", headers["Accept"]
    assert_equal "curl", headers["User-Agent"]
  end

  def test_passes_headers_through_when_send_default_pii_enabled
    event = scrub(event_with_headers("Cookie" => "session=abc"), send_default_pii: true)
    assert_equal "session=abc", event[:request][:headers]["Cookie"]
  end

  def test_tolerates_events_without_a_request
    payload = { exception: { values: [] } }
    assert_equal payload, scrub(payload)
  end

  def test_tolerates_a_request_without_headers
    event = scrub({ request: { url: "http://example.com" } })
    assert_equal "http://example.com", event[:request][:url]
  end
end
