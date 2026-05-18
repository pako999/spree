# frozen_string_literal: true
#
# Add public Cache-Control headers to ActiveStorage representation/blob responses
# so that Cloudflare caches them and doesn't issue bot challenges on subsequent requests.

module SurfStore
  class ActiveStorageCacheHeaders
    def initialize(app)
      @app = app
    end

    def call(env)
      status, headers, body = @app.call(env)

      path = env["PATH_INFO"].to_s
      if path.start_with?("/rails/active_storage/representations/", "/rails/active_storage/blobs/")
        # Allow Cloudflare to cache image representations for 1 year
        # (content-addressed by blob key so stale is impossible)
        headers["Cache-Control"] = "public, max-age=31536000, immutable"
        headers["Vary"] = "Accept-Encoding"
      end

      [status, headers, body]
    end
  end
end

Rails.application.config.middleware.insert_after ActionDispatch::Static, SurfStore::ActiveStorageCacheHeaders
