module Splatty
  module SolidQueue
    class << self
      def install!
        return if @installed
        return unless defined?(::SolidQueue) && ::SolidQueue.respond_to?(:on_thread_error=)
        previous = ::SolidQueue.on_thread_error
        @previous = previous
        ::SolidQueue.on_thread_error = lambda do |exception|
          capture(exception)
          previous.call(exception) if previous.respond_to?(:call)
        end
        @installed = true
      end

      def uninstall!
        return unless @installed
        ::SolidQueue.on_thread_error = @previous
        @previous = nil
        @installed = false
      end

      private

      def capture(exception)
        return unless Splatty.enabled?
        scope = { tags: { "job_backend" => "solid_queue" } }
        thread = Thread.current.name
        scope[:extra] = { "thread" => thread } if thread
        Splatty.capture_exception(exception, **scope)
      end
    end
  end
end
