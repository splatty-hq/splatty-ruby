require "splatty/jobs"

module Splatty
  module Sidekiq
    class ErrorHandler
      def call(exception, context = {}, _config = nil)
        return unless Splatty.enabled?
        Splatty.capture_exception(exception, **scope(context))
      end

      private

      def scope(context)
        context = context.is_a?(Hash) ? context : {}
        job = context[:job] || context["job"]
        job = job.is_a?(Hash) ? job : {}
        job_class = job["wrapped"] || job["class"]

        tags = { "job_backend" => "sidekiq" }
        tags["job_class"] = job_class.to_s if job_class
        tags["job_queue"] = job["queue"].to_s if job["queue"]

        extra = {
          "sidekiq_context" => context[:context] || context["context"],
          "job_id" => job["jid"],
          "job_retry_count" => job["retry_count"],
          "job_args" => Jobs.encode_args(job["args"])
        }.compact

        scope = { tags: tags, extra: extra }
        scope[:transaction] = job_class.to_s if job_class
        scope
      end
    end

    class << self
      def install!
        return if @handler
        return unless configurable?
        handler = ErrorHandler.new
        ::Sidekiq.configure_server do |config|
          config.error_handlers << handler unless config.error_handlers.frozen?
        end
        @handler = handler
      end

      def uninstall!
        return unless @handler
        handler = @handler
        @handler = nil
        return unless configurable?
        ::Sidekiq.configure_server do |config|
          config.error_handlers.delete(handler) unless config.error_handlers.frozen?
        end
      end

      private

      def configurable?
        defined?(::Sidekiq) && ::Sidekiq.respond_to?(:configure_server)
      end
    end
  end
end
