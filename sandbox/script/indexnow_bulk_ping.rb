# frozen_string_literal: true
# One-time bulk IndexNow submission for all active products and taxon pages.
# Run once after initial setup: bin/kamal app exec --reuse "bin/rails runner /rails/script/indexnow_bulk_ping.rb"

require 'net/http'
require 'json'

INDEX_NOW_KEY  = 'e0888a39a40a260f9b71b0c1cc3f5ca6'
INDEX_NOW_HOST = 'api.indexnow.org'
SITE_HOST      = 'www.surf-store.com'
BATCH_SIZE     = 10_000  # IndexNow allows up to 10,000 URLs per request

def ping_batch(urls)
  uri = URI("https://#{INDEX_NOW_HOST}/indexnow")
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
    puts "  → HTTP #{res.code} (#{urls.size} URLs)"
  end
rescue => e
  puts "  → ERROR: #{e.message}"
end

spree = Spree::Core::Engine.routes.url_helpers
store = Spree::Store.default
base  = store.formatted_url_or_custom_domain

# Collect all URLs
urls = ["#{base}/"]

puts "Collecting product URLs..."
I18n.with_locale(:en) do
  Spree::Product.active.find_each do |product|
    urls << "#{base}#{spree.product_path(product)}"
  end
end
puts "  #{urls.size} product URLs"

puts "Collecting taxon URLs..."
I18n.with_locale(:en) do
  Spree::Taxon.includes(:taxonomy).find_each do |taxon|
    next if taxon.root?
    next if taxon.taxonomy&.name&.downcase == 'tags'
    urls << "#{base}#{spree.nested_taxons_path(taxon)}"
  end
end
puts "  #{urls.size} total URLs"

# Add policy pages
Spree::Policy.find_each { |p| urls << "#{base}/policies/#{p.slug}" }
puts "  #{urls.size} total URLs including policies"

# Submit in batches
urls.uniq!
urls.each_slice(BATCH_SIZE).with_index(1) do |batch, i|
  puts "Submitting batch #{i} (#{batch.size} URLs)..."
  ping_batch(batch)
end

puts "\nDone. #{urls.size} URLs submitted to IndexNow."
