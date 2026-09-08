require "test_helper"

class RailsLogTagsTest < Minitest::Test
  def test_defaults_the_unset_case_to_a_named_request_id
    assert_equal({ request_id: :request_id }, Splatty.rails_log_tags(nil))
  end

  def test_converts_a_symbol_array_into_named_tags
    assert_equal({ request_id: :request_id }, Splatty.rails_log_tags([:request_id]))
    assert_equal({ request_id: :request_id, remote_ip: :remote_ip },
      Splatty.rails_log_tags([:request_id, :remote_ip]))
  end

  def test_leaves_a_hash_untouched
    tags = { request_id: ->(req) { req.request_id } }
    assert_same tags, Splatty.rails_log_tags(tags)
  end

  def test_leaves_an_array_with_unnameable_entries_untouched
    tags = [:request_id, ->(req) { req.remote_ip }]
    assert_same tags, Splatty.rails_log_tags(tags)

    tags = ["static-tag"]
    assert_same tags, Splatty.rails_log_tags(tags)
  end

  def test_an_explicitly_empty_array_stays_empty
    assert_equal({}, Splatty.rails_log_tags([]))
  end
end
