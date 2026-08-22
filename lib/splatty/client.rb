module Splatty
  class Client
    attr_reader :configuration, :transport

    def initialize(configuration)
      @configuration = configuration
      @transport = Transport.new(configuration)
      @scrubber = Scrubber.new(configuration)
    end

    def capture_exception(exception, **scope)
      event = Event.from_exception(exception, configuration, scope: scope)
      event = process(event)
      return nil unless event
      transport.send_envelope(event)
      event[:event_id]
    end

    def capture_message(message, level: :info, **scope)
      event = Event.from_message(message, configuration, level: level, scope: scope)
      event = process(event)
      return nil unless event
      transport.send_envelope(event)
      event[:event_id]
    end

    def close
      @transport.close_connections
    end

    private

    def process(event)
      filter(@scrubber.scrub(event))
    end

    def filter(event)
      hook = configuration.before_send
      return event unless hook
      hook.call(event)
    end
  end
end
