module Splatty
  class Railtie < ::Rails::Railtie
    initializer "splatty.middleware" do |app|
      app.middleware.use Splatty::Rack::CaptureExceptions
    end

    # rails_semantic_logger captures config.log_tags inside its :initialize_logger
    # replacement, so the reshape has to be sequenced before that; a plain
    # initializer would run too late.
    initializer "splatty.log_tags", before: :initialize_logger do |app|
      app.config.log_tags = Splatty.rails_log_tags(app.config.log_tags) if defined?(::RailsSemanticLogger)
    end
  end
end

# Has to happen here rather than from Splatty.init: rails_semantic_logger takes
# Rails' :initialize_logger over as it loads, which an initializer is far too
# late for. See Splatty.capture_rails_logs? for what decides it.
require "rails_semantic_logger" if Splatty.capture_rails_logs?(::Rails.env)
