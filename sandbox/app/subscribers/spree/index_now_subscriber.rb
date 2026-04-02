# frozen_string_literal: true

# Pings IndexNow (Bing, Yandex, others) when products or taxons are created/updated.
# IndexNow tells search engines about new/changed URLs instantly, no crawl delay.
# Key file must exist at public/{INDEXNOW_KEY}.txt — served as a static file.
#
# Register at: https://www.bing.com/webmasters/indexnow
module Spree
  class IndexNowSubscriber < Spree::Subscriber
    subscribes_to 'product.created'
    subscribes_to 'product.updated'

    INDEX_NOW_KEY  = 'e0888a39a40a260f9b71b0c1cc3f5ca6'
    INDEX_NOW_HOST = 'api.indexnow.org'

    def handle(event)
      url = url_for_event(event)
      return unless url

      ping(url)
    rescue => e
      Rails.error.report(e, context: { event: event.name })
    end

    private

    def url_for_event(event)
      payload = event.payload
      slug = payload['slug'].presence
      return unless slug

      store = Spree::Store.default
      "#{store.formatted_url_or_custom_domain}/products/#{slug}"
    end

    def ping(url)
      uri = URI("https://#{INDEX_NOW_HOST}/indexnow")
      Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: 5, read_timeout: 5) do |http|
        req = Net::HTTP::Get.new(uri)
        params = { url: url, key: INDEX_NOW_KEY }
        req.set_form_data(params)
        uri.query = URI.encode_www_form(params)
        http.get("#{uri.path}?#{uri.query}")
      end
    end
  end
end

require 'net/http'
