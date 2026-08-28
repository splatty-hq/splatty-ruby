require "securerandom"
require "socket"
require "time"

module Splatty
  class Event
    APP_ROOT_REGEXP = %r{\A(?:/app/|#{Regexp.escape(Dir.pwd)}/)}

    def self.from_exception(exception, configuration, scope: {})
      builder = new(configuration)
      builder.build_exception(exception, scope)
    end

    def self.from_message(message, configuration, level: :info, scope: {})
      builder = new(configuration)
      builder.build_message(message, level, scope)
    end

    def self.line_cache
      @line_cache ||= LineCache.new
    end

    def initialize(configuration)
      @configuration = configuration
    end

    def build_exception(exception, scope)
      base_payload(scope).merge(
        level: scope[:level] || "error",
        exception: { values: exception_chain(exception) }
      )
    end

    def build_message(message, level, scope)
      base_payload(scope).merge(
        level: level.to_s,
        message: { formatted: message.to_s }
      )
    end

    private

    def base_payload(scope)
      {
        event_id: SecureRandom.hex(16),
        timestamp: Time.now.utc.iso8601,
        platform: "ruby",
        environment: @configuration.environment,
        release: @configuration.release,
        server_name: @configuration.server_name || Socket.gethostname,
        sdk: { name: Splatty::Transport::SDK_NAME, version: Splatty::VERSION },
        transaction: scope[:transaction],
        tags: scope[:tags] || {},
        extra: scope[:extra] || {},
        contexts: contexts(scope),
        request: scope[:request] || nil
      }.compact
    end

    def contexts(scope)
      {
        runtime: { name: "ruby", version: RUBY_VERSION }
      }.merge(scope[:contexts] || {})
    end

    def exception_chain(exception)
      chain = []
      current = exception
      seen = Set.new
      while current && !seen.include?(current.object_id)
        seen << current.object_id
        chain.unshift(exception_value(current))
        current = current.respond_to?(:cause) ? current.cause : nil
      end
      chain
    end

    def exception_value(exception)
      {
        type: exception.class.name,
        value: exception.message.to_s,
        stacktrace: { frames: frames(exception) }
      }
    end

    def frames(exception)
      backtrace = exception.backtrace_locations || synthesize_locations(exception.backtrace)
      Array(backtrace).reverse.map { |loc| frame(loc) }
    end

    def synthesize_locations(lines)
      Array(lines).map do |line|
        match = line.match(/\A(?<file>[^:]+):(?<lineno>\d+)(?::in `(?<func>[^']+)')?/)
        next nil unless match
        SyntheticLocation.new(match[:file], match[:lineno].to_i, match[:func])
      end.compact
    end

    def frame(loc)
      filename = loc.respond_to?(:absolute_path) ? (loc.absolute_path || loc.path) : loc.path
      function = loc.respond_to?(:label) ? loc.label : loc.function
      frame = {
        filename: short_filename(filename),
        abs_path: filename,
        function: function,
        lineno: loc.lineno,
        in_app: in_app?(filename)
      }
      context = Event.line_cache.context(filename, loc.lineno, @configuration.context_lines)
      context ? frame.merge(context) : frame
    end

    def short_filename(path)
      return path unless path
      path.sub(APP_ROOT_REGEXP, "")
    end

    def in_app?(path)
      return false unless path
      !!(path.match?(APP_ROOT_REGEXP) && !path.include?("/gems/") && !path.include?("/ruby/"))
    end

    SyntheticLocation = Struct.new(:path, :lineno, :function)
  end
end

require "set"
