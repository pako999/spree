# frozen_string_literal: true
#
# Warms the fragment cache for top category pages immediately after deploy.
# Prevents the first real visitor from waiting 5s on a cold cache.
#
# Triggered by: config/initializers/warm_cache_on_boot.rb
# Also scheduled daily at 05:00 to refresh stale entries.
class WarmCacheJob < ApplicationJob
  queue_as :background

  # Top categories to pre-warm — ordered by traffic importance
  TAXON_SLUGS = %w[
    kitesurfing
    windsurf
    wetsuits
    harnesses
    accessories
    sup
    wing-foiling
    brands/duotone-kiteboarding
    brands/duotone-windsurfing
    brands/ion-water
  ].freeze

  def perform
    store = Spree::Store.default
    return unless store

    store_url = store.formatted_url_or_custom_domain
    Rails.logger.info "[WarmCacheJob] warming #{TAXON_SLUGS.size} category pages"

    TAXON_SLUGS.each do |slug|
      url = "#{store_url}/t/#{slug}"
      begin
        response = Net::HTTP.get_response(URI(url))
        Rails.logger.info "[WarmCacheJob] #{response.code} #{url}"
      rescue StandardError => e
        Rails.logger.warn "[WarmCacheJob] failed #{url}: #{e.message}"
      end
    end

    Rails.logger.info "[WarmCacheJob] done"
  end
end
