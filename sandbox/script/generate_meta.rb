#!/usr/bin/env ruby
# Generate SEO meta_title and meta_description for products missing them.
# Safe to re-run — skips products that already have values set.
#
# meta_title format: "Product Name | Brand | Category - Buy at Surf-store.com"
# meta_description format: First 155 chars of product description, cleaned of HTML, ending with " | Shop at Surf-store.com"

require 'action_view'
include ActionView::Helpers::SanitizeHelper

brand_tid = Spree::Taxonomy.find_by(name: 'Brands')&.id
cat_tid   = Spree::Taxonomy.find_by(name: 'Categories')&.id

products = Spree::Product.where(status: 'active').includes(taxons: [:taxonomy])
total = products.count
title_updated = 0
desc_updated  = 0

puts "Processing #{total} active products..."

products.find_each(batch_size: 200) do |p|
  changed = false

  # --- META TITLE ---
  if p.meta_title.blank?
    brand = p.taxons.select { |t| t.taxonomy_id == brand_tid }
                     .max_by { |t| t.depth.to_i }&.name
    category = p.taxons.select { |t| t.taxonomy_id == cat_tid }
                        .max_by { |t| t.depth.to_i }&.name

    parts = [p.name.strip]
    # Add brand if not already in name
    parts << brand if brand && !p.name.downcase.include?(brand.downcase)
    # Add category if not already in name or brand
    parts << category if category && !parts.join(' ').downcase.include?(category.downcase)

    meta_title = parts.join(' | ') + ' - Buy at Surf-store.com'

    # Google truncates at ~60 chars; trim smartly
    if meta_title.length > 60
      meta_title = parts.join(' | ')
      if meta_title.length > 55
        meta_title = p.name.strip + ' | Surf-store.com'
      else
        meta_title += ' | Surf-store.com'
      end
    end
    meta_title = meta_title[0..59] if meta_title.length > 60

    p.meta_title = meta_title
    changed = true
    title_updated += 1
  end

  # --- META DESCRIPTION ---
  if p.meta_description.blank?
    if p.description.present?
      # Strip HTML, normalize whitespace
      clean = strip_tags(p.description.to_s).gsub(/\s+/, ' ').strip
      # Take first ~140 chars, cut at word boundary
      if clean.length > 140
        truncated = clean[0..139].sub(/\s+\S*$/, '')
        meta_desc = truncated + '... | Shop at Surf-store.com'
      else
        meta_desc = clean + ' | Shop at Surf-store.com'
      end
    else
      # No description at all — build from name + brand + category
      brand = p.taxons.select { |t| t.taxonomy_id == brand_tid }
                       .max_by { |t| t.depth.to_i }&.name
      category = p.taxons.select { |t| t.taxonomy_id == cat_tid }
                          .max_by { |t| t.depth.to_i }&.name
      meta_desc = "Buy #{p.name}"
      meta_desc += " by #{brand}" if brand
      meta_desc += " in #{category}" if category
      meta_desc += ". Free shipping in Europe. Official dealer. | Surf-store.com"
    end

    # Google truncates at ~155-160 chars
    meta_desc = meta_desc[0..159] if meta_desc.length > 160

    p.meta_description = meta_desc
    changed = true
    desc_updated += 1
  end

  p.save!(touch: false) if changed
  print "." if (title_updated + desc_updated) % 50 == 0
end

puts
puts "=" * 60
puts "Meta titles generated  : #{title_updated}"
puts "Meta descriptions generated: #{desc_updated}"
puts "Total active products  : #{total}"
