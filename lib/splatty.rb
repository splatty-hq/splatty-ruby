require "splatty/version"
require "splatty/configuration"
require "splatty/transport"
require "splatty/event"
require "splatty/scrubber"
require "splatty/client"
require "splatty/semantic_logger"
require "splatty/jobs"
require "splatty/active_job"
require "splatty/sidekiq"
require "splatty/solid_queue"

module Splatty
  class Error < StandardError; end

  CAPTURED_IVAR = :@__splatty_captured

  class << self
    def init
      configuration = Configuration.new
      yield configuration if block_given?
      configuration.validate!
      @client = Client.new(configuration)
      if configuration.enabled?
        install_log_appender if configuration.logs
        install_integrations
      end
      @client
    end

    def client
      @client
    end

    def configuration
      @client&.configuration
    end

    def enabled?
      !@client.nil? && @client.configuration.enabled?
    end

    def capture_exception(exception, **opts)
      return nil unless enabled?
      return nil if already_captured?(exception)
      mark_captured(exception)
      @client.capture_exception(exception, **opts)
    end

    def capture_message(message, level: :info, **opts)
      return nil unless enabled?
      @client.capture_message(message, level: level, **opts)
    end

    def close
      uninstall_log_appender
      uninstall_integrations
      @client&.close
      @client = nil
    end

    private

    def already_captured?(exception)
      exception.is_a?(Exception) && exception.instance_variable_defined?(CAPTURED_IVAR)
    end

    def mark_captured(exception)
      return unless exception.is_a?(Exception)
      return if exception.frozen?
      exception.instance_variable_set(CAPTURED_IVAR, true)
    end

    def install_integrations
      ActiveJob.install!
      Sidekiq.install!
      SolidQueue.install!
    end

    def uninstall_integrations
      ActiveJob.uninstall!
      Sidekiq.uninstall!
      SolidQueue.uninstall!
    end

    def install_log_appender
      return if @log_appender
      @log_appender = ::SemanticLogger.add_appender(appender: Splatty::SemanticLogger::Appender.new)
    end

    def uninstall_log_appender
      return unless @log_appender
      ::SemanticLogger.remove_appender(@log_appender)
      @log_appender = nil
    end
  end
end

require "splatty/rack" if defined?(Rack)
require "splatty/railtie" if defined?(Rails::Railtie)
