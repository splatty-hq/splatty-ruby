require "splatty/jobs"

module Splatty
  module ActiveJob
    EVENT_NAME = "perform.active_job".freeze

    class << self
      def install!
        return if @subscriber
        return unless defined?(::ActiveSupport::Notifications)
        @subscriber = ::ActiveSupport::Notifications.subscribe(EVENT_NAME) do |_name, _start, _finish, _id, payload|
          capture(payload)
        end
      end

      def uninstall!
        return unless @subscriber
        ::ActiveSupport::Notifications.unsubscribe(@subscriber)
        @subscriber = nil
      end

      private

      def capture(payload)
        exception = payload[:exception_object]
        return unless exception
        return unless Splatty.enabled?
        Splatty.capture_exception(exception, **scope(payload[:job]))
      end

      def scope(job)
        return { tags: { "job_backend" => "active_job" } } unless job

        tags = {
          "job_backend" => backend(job),
          "job_class" => job.class.name.to_s,
          "job_queue" => job.queue_name.to_s
        }

        extra = {
          "job_id" => job.job_id,
          "job_executions" => job.executions,
          "provider_job_id" => job.provider_job_id,
          "job_args" => Jobs.encode_args(arguments(job))
        }.compact

        { tags: tags, extra: extra, transaction: job.class.name.to_s }
      end

      def backend(job)
        return "active_job" unless job.class.respond_to?(:queue_adapter_name)
        job.class.queue_adapter_name.to_s
      end

      def arguments(job)
        ::ActiveJob::Arguments.serialize(job.arguments)
      rescue ::ActiveJob::SerializationError, ::ActiveJob::DeserializationError
        nil
      end
    end
  end
end
