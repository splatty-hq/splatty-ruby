require "splatty/version"
require "splatty/configuration"
require "splatty/transport"
require "splatty/event"
require "splatty/client"

module Splatty
  class Error < StandardError; end

  class << self
    def init
      configuration = Configuration.new
      yield configuration if block_given?
      configuration.validate!
      @client = Client.new(configuration)
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
      @client&.close
      @client = nil
    end
  end
end

require "splatty/rack" if defined?(Rack)
require "splatty/semantic_logger" if defined?(SemanticLogger)
require "splatty/railtie" if defined?(Rails::Railtie)
