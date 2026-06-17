module Splatty
  class Railtie < ::Rails::Railtie
    initializer "splatty.middleware" do |app|
      app.middleware.use Splatty::Rack::CaptureExceptions
    end
  end
end
