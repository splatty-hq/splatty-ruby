require "test_helper"
require "tmpdir"

class LineCacheTest < Minitest::Test
  def setup
    @cache = Splatty::LineCache.new
    @dir = Dir.mktmpdir
    @path = File.join(@dir, "sample.rb")
    File.write(@path, (1..10).map { |i| "line #{i}" }.join("\n"))
  end

  def teardown
    FileUtils.remove_entry(@dir)
  end

  def test_returns_surrounding_lines
    context = @cache.context(@path, 5, 2)

    assert_equal [ "line 3", "line 4" ], context[:pre_context]
    assert_equal "line 5", context[:context_line]
    assert_equal [ "line 6", "line 7" ], context[:post_context]
  end

  def test_clamps_at_file_boundaries
    first = @cache.context(@path, 1, 3)
    assert_equal [], first[:pre_context]
    assert_equal "line 1", first[:context_line]
    assert_equal [ "line 2", "line 3", "line 4" ], first[:post_context]

    last = @cache.context(@path, 10, 3)
    assert_equal [ "line 7", "line 8", "line 9" ], last[:pre_context]
    assert_equal "line 10", last[:context_line]
    assert_equal [], last[:post_context]
  end

  def test_returns_nil_for_unreadable_or_out_of_range
    assert_nil @cache.context(File.join(@dir, "missing.rb"), 3, 2)
    assert_nil @cache.context(@dir, 3, 2)
    assert_nil @cache.context(@path, 99, 2)
    assert_nil @cache.context(@path, 0, 2)
    assert_nil @cache.context(nil, 3, 2)
    assert_nil @cache.context(@path, 3, 0)
  end

  def test_picks_up_file_changes
    assert_equal "line 5", @cache.context(@path, 5, 1)[:context_line]

    File.write(@path, (1..10).map { |i| "changed #{i}" }.join("\n"))
    File.utime(Time.now + 2, Time.now + 2, @path)

    assert_equal "changed 5", @cache.context(@path, 5, 1)[:context_line]
  end

  def test_truncates_long_lines
    File.write(@path, "x" * (Splatty::LineCache::MAX_LINE_LENGTH + 500))
    assert_equal Splatty::LineCache::MAX_LINE_LENGTH, @cache.context(@path, 1, 1)[:context_line].length
  end

  def test_skips_oversized_files
    File.write(@path, "a\n" * Splatty::LineCache::MAX_FILE_BYTES)
    assert_nil @cache.context(@path, 1, 1)
  end

  def test_scrubs_invalid_encoding
    File.binwrite(@path, "caf\xC3\x28 = 1\n")
    assert @cache.context(@path, 1, 1)[:context_line].valid_encoding?
  end
end
