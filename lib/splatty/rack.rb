module Splatty
  module Rack
    class CaptureExceptions
      def initialize(app)
        @app = app
      end

      def call(env)
        @app.call(env)
      rescue Exception => e
        capture(e, env)
        raise
      end

      private

      def capture(exception, env)
        return unless Splatty.enabled?
        request = build_request(env)
        scope = { request: request }
        request_id = env["action_dispatch.request_id"] || env["HTTP_X_REQUEST_ID"]
        scope[:tags] = { "request_id" => request_id.to_s } if request_id
        Splatty.capture_exception(exception, **scope)
      end

      def build_request(env)
        scheme = env["rack.url_scheme"] || "http"
        host = env["HTTP_HOST"] || env["SERVER_NAME"]
        path = env["PATH_INFO"].to_s
        qs = env["QUERY_STRING"].to_s
        url = "#{scheme}://#{host}#{path}"
        url = "#{url}?#{qs}" unless qs.empty?
        {
          url: url,
          method: env["REQUEST_METHOD"],
          headers: collect_headers(env)
        }
      end

      def collect_headers(env)
        env.each_with_object({}) do |(k, v), acc|
          next unless k.is_a?(String)
          if k.start_with?("HTTP_")
            acc[k.sub("HTTP_", "").split("_").map(&:capitalize).join("-")] = v.to_s
          end
        end
      end
    end
  end
end
