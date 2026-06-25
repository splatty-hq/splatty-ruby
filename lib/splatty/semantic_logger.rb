require "semantic_logger"

module Splatty
  module SemanticLogger
    class Appender < ::SemanticLogger::Subscriber
      DEFAULT_BATCH_SIZE = 100
      DEFAULT_FLUSH_INTERVAL = 15.0
      DEFAULT_QUEUE_LIMIT = 5_000

      # Drop log entries describing requests to Splatty's own intake endpoints.
      # Without this, dogfooded apps (the Splatty server logging to itself)
      # generate a positive feedback loop: every shipped batch becomes a new
      # set of Rails request logs, which become another batch, etc.
      INTAKE_PATH_PATTERN = %r{\A/api/\d+/(logs|metrics|envelope)/?\z}.freeze

      def initialize(level: nil, batch_size: DEFAULT_BATCH_SIZE,
                     flush_interval: DEFAULT_FLUSH_INTERVAL,
                     queue_limit: DEFAULT_QUEUE_LIMIT, host: nil, **args)
        @batch_size = batch_size
        @flush_interval = flush_interval
        @queue_limit = queue_limit
        @queue = Queue.new
        @mutex = Mutex.new
        @running = true
        super(level: level, **args)
        @host = host || Socket.gethostname
        start_worker
      end

      def log(log)
        return false unless Splatty.enabled?
        return false if intake_request?(log)
        if @queue.size >= @queue_limit
          @queue.pop
        end
        @queue << build_entry(log)
        true
      end

      def intake_request?(log)
        named_tags = log.named_tags.is_a?(Hash) ? log.named_tags : {}
        payload = log.payload.is_a?(Hash) ? log.payload : {}
        path = (named_tags[:path] || named_tags["path"] || payload[:path] || payload["path"]).to_s
        return false if path.empty?
        INTAKE_PATH_PATTERN.match?(path)
      end

      def flush
        drain
      end

      def close
        @running = false
        @worker&.wakeup if @worker&.alive?
        @worker&.join(2)
        drain
        true
      end

      private

      def start_worker
        @worker = Thread.new do
          while @running
            begin
              sleep @flush_interval
              drain
            rescue StandardError
              nil
            end
          end
        end
        @worker.name = "splatty-log-flusher"
      end

      def drain
        return if @queue.empty?
        @mutex.synchronize do
          batch = []
          batch << @queue.pop(true) while batch.size < @batch_size * 4 && !@queue.empty?
          dispatch(batch) unless batch.empty?
        end
      rescue ThreadError
        nil
      end

      def dispatch(batch)
        return unless Splatty.enabled?
        Splatty.client.transport.send_logs(host: @host, logs: batch)
      end

      def build_entry(log)
        payload = log.payload.is_a?(Hash) ? log.payload : {}
        named_tags = log.named_tags.is_a?(Hash) ? log.named_tags : {}
        fields = stringify_fields(payload.merge(named_tags))
        {
          timestamp: ((log.time || Time.now).utc.to_f * 1000).to_i,
          level: map_level(log.level),
          message: log.message.to_s,
          request_id: extract_field(fields, "request_id"),
          method: extract_field(fields, "method"),
          path: extract_field(fields, "path"),
          status: extract_int(fields, "status"),
          duration_ms: extract_float(fields, "duration_ms") || extract_float(fields, "duration"),
          controller: extract_field(fields, "controller"),
          action: extract_field(fields, "action"),
          environment: Splatty.configuration&.environment.to_s,
          release: Splatty.configuration&.release.to_s,
          host: @host,
          fields: fields
        }
      end

      def map_level(level)
        case level.to_s
        when "trace", "debug" then "debug"
        when "info" then "info"
        when "warn" then "warn"
        when "error" then "error"
        when "fatal" then "fatal"
        else "info"
        end
      end

      def stringify_fields(hash)
        hash.each_with_object({}) do |(k, v), acc|
          acc[k.to_s] = v.is_a?(String) ? v : v.inspect
        end
      end

      def extract_field(hash, key)
        val = hash.delete(key)
        val.to_s
      end

      def extract_int(hash, key)
        val = hash.delete(key)
        Integer(val) rescue 0
      end

      def extract_float(hash, key)
        val = hash.delete(key)
        Float(val) rescue nil
      end
    end
  end
end
