# frozen_string_literal: true
require 'benchmark'

store = Spree::Store.find(2)
taxon = Spree::Taxon.find_by(permalink: 'categories/kitesurfing/kites')

puts "Taxon: #{taxon.name} (#{taxon.permalink})"
puts "Descendants: #{taxon.cached_self_and_descendants_ids.size} taxon IDs"

# Simulate what storefront_products returns
scope = Spree::Product.active.for_store(store).in_taxon(taxon)
puts "Total products in taxon: #{scope.count}"

inc = {
  taxons: [:taxonomy],
  taggings: [],
  master: [:images, :prices, :stock_locations, { stock_items: :stock_location }],
  variants: [:images, :prices, :option_values, :stock_locations, { stock_items: :stock_location }],
  option_types: []
}

puts "\n=== Cold (first load) ==="
puts Benchmark.measure {
  scope.includes(inc).preload_associations_lazily.limit(20).to_a
}

puts "\n=== Warm (second load) ==="
puts Benchmark.measure {
  scope.includes(inc).preload_associations_lazily.limit(20).to_a
}

# Count queries for one page
puts "\n=== Query count for one page (20 products) ==="
query_count = 0
counter = ->(*, **) { query_count += 1 }
ActiveSupport::Notifications.subscribed(counter, 'sql.active_record') do
  scope.includes(inc).preload_associations_lazily.limit(20).to_a
end
puts "Queries: #{query_count}"

# Check if EXPLAIN shows seq scan on products_taxons
puts "\n=== EXPLAIN products_taxons ==="
plan = ActiveRecord::Base.connection.execute(
  "EXPLAIN (ANALYZE, COSTS OFF, TIMING OFF) " \
  "SELECT * FROM spree_products_taxons " \
  "WHERE taxon_id IN (#{taxon.cached_self_and_descendants_ids.join(',')}) " \
  "ORDER BY position LIMIT 20"
)
plan.each { |r| puts r.values.first }
