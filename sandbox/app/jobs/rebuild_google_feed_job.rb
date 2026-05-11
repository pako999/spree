# Clears the Google Shopping feed cache so it rebuilds fresh on next request.
# Scheduled every 6 hours to ensure:
#   - New products appear promptly
#   - Out-of-stock items are removed after stock syncs run
#   - Stock changes from sync jobs (BAM, Pryde, Gaastra, Nobile, etc.) are reflected
class RebuildGoogleFeedJob < ApplicationJob
  queue_as :background

  FEED_CACHE_KEY = 'feeds/google_shopping_v6'

  def perform
    Rails.cache.delete(FEED_CACHE_KEY)
    Rails.logger.info "[RebuildGoogleFeedJob] Feed cache cleared — will rebuild on next request"

    # Warm the cache immediately by issuing an internal HTTP request
    require 'net/http'
    uri = URI("http://127.0.0.1:#{ENV.fetch('PORT', 3000)}/feeds/google-shopping.xml")
    req = Net::HTTP::Get.new(uri)
    req['Host'] = ENV.fetch('APP_HOST', 'www.surf-store.com')
    Net::HTTP.start(uri.hostname, uri.port, read_timeout: 120) do |http|
      http.request(req)
    end
    Rails.logger.info "[RebuildGoogleFeedJob] Feed warmed successfully"
  rescue => e
    Rails.logger.error "[RebuildGoogleFeedJob] Error: #{e.message}"
    Rails.error.report(e)
  end
end
