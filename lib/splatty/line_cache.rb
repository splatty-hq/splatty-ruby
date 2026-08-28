module Splatty
  class LineCache
    MAX_FILES = 100
    MAX_FILE_BYTES = 512 * 1024
    MAX_LINE_LENGTH = 1000

    def initialize
      @mutex = Mutex.new
      @files = {}
    end

    def context(path, lineno, context_lines)
      lineno = lineno.to_i
      context_lines = context_lines.to_i
      return nil if path.to_s.empty? || lineno < 1 || context_lines < 1

      lines = lines_for(path)
      return nil unless lines

      index = lineno - 1
      current = lines[index]
      return nil unless current

      {
        pre_context: lines[[ index - context_lines, 0 ].max...index] || [],
        context_line: current,
        post_context: lines[(index + 1)..(index + context_lines)] || []
      }
    end

    def clear
      @mutex.synchronize { @files.clear }
    end

    private

    def lines_for(path)
      stat = stat_for(path)
      return nil unless stat

      key = [ path, stat.mtime.to_f, stat.size ]
      @mutex.synchronize do
        return @files[key] if @files.key?(key)
        @files.shift while @files.size >= MAX_FILES
        @files[key] = read(path)
      end
    end

    def stat_for(path)
      stat = File.stat(path)
      return nil unless stat.file? && stat.size.positive? && stat.size <= MAX_FILE_BYTES
      stat
    rescue Errno::ENOENT, Errno::EACCES, Errno::ENAMETOOLONG, Errno::ELOOP, Errno::ENOTDIR
      nil
    end

    def read(path)
      File.readlines(path, chomp: true).map { |line| line.scrub[0, MAX_LINE_LENGTH] }
    rescue Errno::ENOENT, Errno::EACCES, Errno::EISDIR, Errno::ENOTDIR, IOError
      nil
    end
  end
end
