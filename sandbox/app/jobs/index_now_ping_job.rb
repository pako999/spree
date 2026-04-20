# frozen_string_literal: true
#
# Weekly job: submits all active product + taxon URLs to IndexNow
# so search engines pick up new/updated pages quickly.
#
# Scheduled via config/recurring.yml  →  every Monday at 04:00
class IndexNowPingJob < ApplicationJob
  queue_as :background

  INDEX_NOW_KEY  = 'e0888a39a40a260f9b71b0c1cc3f5ca6'
  INDEX_NOW_HOST = 'api.indexnow.org'
  SITE_HOST      = 'www.surf-store.com'
  BATCH_SIZE     = 10_000

  def perform
    spree_routes = Spree::Core::Engine.routes.url_helpers
    store        = Spree::Store.default
    base         = store.formatted_url_or_custom_domain

    urls = ["#{base}/"]

    I18n.with_locale(:en) do
      Spree::Product.active.find_each { |p| urls << "#{base}#{spree_routes.product_path(p)}" }
      Spree::Taxon.includes(:taxonomy).find_each do |t|
        next if t.root?
        next if t.taxonomy&.name&.downcase == 'tags'
        urls << "#{base}#{spree_routes.nested_taxons_path(t)}"
      end
    end

    Spree::Policy.find_each { |p| urls << "#{base}/policies/#{p.slug}" }

    urls.uniq!
    submitted = 0
    urls.each_slice(BATCH_SIZE) do |batch|
      ping(batch)
      submitted += batch.size
    end

    Rails.logger.info "[IndexNowPingJob] submitted #{submitted} URLs to IndexNow"
  end

  private

  def ping(urls)
    require 'net/http'

    uri  = URI("https://#{INDEX_NOW_HOST}/indexnow")
    body = {
      host: SITE_HOST,
      key: INDEX_NOW_KEY,
      keyLocation: "https://#{SITE_HOST}/#{INDEX_NOW_KEY}.txt",
      urlList: urls
    }.to_json

    Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: 10, read_timeout: 30) do |http|
      req = Net::HTTP::Post.new(uri, 'Content-Type' => 'application/json; charset=utf-8')
      req.body = body
      res = http.request(req)
      Rails.logger.info "[IndexNowPingJob] HTTP #{res.code} (#{urls.size} URLs)"
    end
  rescue StandardError => e
    Rails.logger.error "[IndexNowPingJob] ping failed: #{e.message}"
  end
end
