# frozen_string_literal: true

# Adds Cloudflare-friendly HTTP cache headers to read-only storefront pages.
# Cloudflare caches responses with s-maxage; the browser gets a shorter TTL.
# Pages with user-specific Turbo frames (cart, account) are safe to cache
# because those frames are loaded separately after the page arrives.
module Spree
  module CacheableStorefront
    extend ActiveSupport::Concern

    included do
      after_action :set_storefront_cache_headers, only: %i[show index]
    end

    private

    def set_storefront_cache_headers
      return if response.status != 200
      return if request.post? || request.patch? || request.put? || request.delete?
      return if try(:current_spree_user).present?  # never cache logged-in pages at edge

      # Cloudflare: cache for 2 minutes at edge, browser revalidates after 30s
      response.set_header('Cache-Control', 'public, max-age=30, s-maxage=120, stale-while-revalidate=60')

      # Strip Set-Cookie so Cloudflare can cache the HTML response.
      # Only safe when the session has no real data (no cart, no flash).
      # The CSRF token is refreshed client-side via /csrf_token.json when needed.
      strip_session_cookie_for_cdn
    end

    def strip_session_cookie_for_cdn
      # Session keys that are safe to ignore — they don't represent user-specific state
      # that should prevent caching (e.g. no cart, no geo-detected currency).
      ignorable = %w[_csrf_token session_id flash]
      meaningful = session.to_hash.except(*ignorable)
      return if meaningful.any?

      # response.headers.delete('Set-Cookie') does NOT work: the session
      # middleware (ActionDispatch::Session::CookieStore) adds the cookie
      # AFTER Rails action processing completes, overwriting any header delete.
      # request.session_options[:skip] = true tells the middleware not to set
      # the cookie at all — this is the correct Rails way to suppress it.
      request.session_options[:skip] = true
    end
  end
end
