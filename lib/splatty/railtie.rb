module Splatty
  class Railtie < ::Rails::Railtie
    initializer "splatty.middleware" do |app|
      app.middleware.use Splatty::Rack::CaptureExceptions
    end
  end
end

# Has to happen here rather than from Splatty.init: rails_semantic_logger takes
# Rails' :initialize_logger over as it loads, which an initializer is far too
# late for. See Splatty.capture_rails_logs? for what decides it.
require "rails_semantic_logger" if Splatty.capture_rails_logs?(::Rails.env)
