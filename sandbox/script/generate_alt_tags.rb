#!/usr/bin/env ruby
# Generate SEO-optimized alt tags for all product images that have none.
# Format: "<Product Name> - <Brand> <Category> | Surf-store.com"
# Skips any image that already has alt text set.
#
# Run: kamal app exec --reuse "bin/rails runner /rails/tmp/generate_alt_tags.rb"

require 'set'

total  = 0
updated = 0
skipped = 0
no_prod = 0

# Preload variant → product mapping to avoid per-row DB lookups
puts "Preloading product/variant/taxon data..."
products_by_id = Spree::Product.includes(taxons: [:taxonomy]).index_by(&:id)
variants_by_id = {}
Spree::Variant.unscoped.find_each(batch_size: 1000) do |v|
  variants_by_id[v.id] = v
end
puts "Loaded #{products_by_id.size} products and #{variants_by_id.size} variants"

# Preload taxonomy → taxons map to identify brand vs category
brand_taxonomy_id = Spree::Taxonomy.find_by(name: 'Brands')&.id
cat_taxonomy_id   = Spree::Taxonomy.find_by(name: 'Categories')&.id
puts "Brands taxonomy: #{brand_taxonomy_id}, Categories taxonomy: #{cat_taxonomy_id}"

def build_alt(product, brand_taxonomy_id, cat_taxonomy_id)
  return nil unless product

  # Pick the best brand taxon (leaf node — highest depth — under Brands taxonomy)
  brand = product.taxons.select { |t| t.taxonomy_id == brand_taxonomy_id }
                         .max_by { |t| t.depth.to_i }
                         &.name

  # Pick the most-specific category taxon (highest depth) under Categories taxonomy
  category = product.taxons.select { |t| t.taxonomy_id == cat_taxonomy_id }
                            .max_by { |t| t.depth.to_i }
                            &.name

  parts = [product.name.to_s.strip]
  parts << brand if brand && !product.name.to_s.downcase.include?(brand.to_s.downcase)
  parts << category if category && !parts.join(' ').downcase.include?(category.to_s.downcase)

  alt = parts.compact.reject(&:empty?).join(' - ')
  alt += ' | Surf-store.com'
  # Trim to 125 chars for SEO best practice (Google recommends under 125)
  alt = alt[0..124].rstrip if alt.length > 125
  alt
end

puts "Updating images..."
start = Time.current
Spree::Image.where(alt: [nil, '']).in_batches(of: 500) do |batch|
  batch.each do |img|
    total += 1
    variant = variants_by_id[img.viewable_id]
    unless variant
      no_prod += 1
      next
    end
    product = products_by_id[variant.product_id]
    unless product
      no_prod += 1
      next
    end

    alt = build_alt(product, brand_taxonomy_id, cat_taxonomy_id)
    next if alt.blank?

    # Direct UPDATE avoids triggering callbacks / touching updated_at for 21k rows
    Spree::Image.where(id: img.id).update_all(alt: alt)
    updated += 1
  end
  print "."
end

elapsed = (Time.current - start).round
puts
puts "=" * 60
puts "Total processed : #{total}"
puts "Updated         : #{updated}"
puts "Skipped         : #{skipped} (already have alt)"
puts "No product      : #{no_prod}"
puts "Elapsed         : #{elapsed}s"

# Show a few samples
puts "\nSample alt tags:"
Spree::Image.where.not(alt: [nil, '']).order('RANDOM()').limit(8).each do |img|
  puts "  #{img.alt}"
end
