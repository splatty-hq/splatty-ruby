module Splatty
  class Scrubber
    FILTERED = "[Filtered]".freeze
    SENSITIVE_HEADER_PATTERN = /authoriz|cookie|csrf|xsrf|secret|token|password|api[-_]?key|session/i

    def initialize(configuration)
      @configuration = configuration
    end

    def scrub(event)
      return event if @configuration.send_default_pii
      return event unless event.is_a?(Hash)

      request = event[:request]
      scrub_headers(request[:headers]) if request.is_a?(Hash)
      event
    end

    private

    def scrub_headers(headers)
      return unless headers.is_a?(Hash)

      headers.each_key do |name|
        headers[name] = FILTERED if SENSITIVE_HEADER_PATTERN.match?(name.to_s)
      end
    end
  end
end
