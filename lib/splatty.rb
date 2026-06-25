require "splatty/version"
require "splatty/configuration"
require "splatty/transport"
require "splatty/event"
require "splatty/client"
require "splatty/semantic_logger"

module Splatty
  class Error < StandardError; end

  class << self
    def init
      configuration = Configuration.new
      yield configuration if block_given?
      configuration.validate!
      @client = Client.new(configuration)
      install_log_appender if configuration.enabled? && configuration.logs
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
      @client.capture_exception(exception, **opts)
    end

    def capture_message(message, level: :info, **opts)
      return nil unless enabled?
      @client.capture_message(message, level: level, **opts)
    end

    def close
      uninstall_log_appender
      @client&.close
      @client = nil
    end

    private

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
