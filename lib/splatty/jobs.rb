require "json"

module Splatty
  module Jobs
    MAX_ARGS_LENGTH = 2048

    def self.encode_args(args)
      return nil if args.nil?
      json = JSON.generate(args)
      return json if json.length <= MAX_ARGS_LENGTH
      "#{json[0, MAX_ARGS_LENGTH]}...(truncated)"
    rescue JSON::GeneratorError
      nil
    end
  end
end
