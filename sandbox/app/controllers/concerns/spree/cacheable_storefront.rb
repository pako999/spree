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
    end
  end
end
