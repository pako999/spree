#!/usr/bin/env ruby
# frozen_string_literal: true
# Attach orphaned Nobile image blobs to the correct products by slug/name matching.
# Run: bundle exec rails runner /rails/tmp/attach_nobile_images.rb

puts "=== Attaching orphaned Nobile images ==="

# Get all Nobile products without a master image
nobile_products = Spree::Product
  .where("LOWER(name) LIKE '%nobile%'")
  .where(deleted_at: nil)
  .includes(:master)
  .select { |p| Spree::Image.where(viewable: p.master).empty? }

puts "Nobile products needing images: #{nobile_products.size}"

# Get all unattached image blobs with Nobile-related filenames
unattached_blobs = ActiveStorage::Blob
  .left_joins(:attachments)
  .where(active_storage_attachments: { id: nil })
  .where("content_type LIKE 'image/%'")
  .where("byte_size > 5000")
  .where("LOWER(filename) LIKE '%nobile%' OR LOWER(filename) LIKE '%nhp%' OR
          LOWER(filename) LIKE '%nt5%' OR LOWER(filename) LIKE '%horizon%' OR
          LOWER(filename) LIKE '%carpet%' OR LOWER(filename) LIKE '%ifs%' OR
          LOWER(filename) LIKE '%nano%' OR LOWER(filename) LIKE '%fifty%'")
  .order(:filename)

puts "Unattached Nobile blobs: #{unattached_blobs.count}"
puts ""

# Build a searchable index: product slug/name fragments → product
product_index = {}
nobile_products.each do |p|
  # slug e.g. "nobile-2026-nhp-carbon" → ["nhp", "carbon"]
  slug_parts = p.slug.gsub("nobile-", "").gsub(/\d{4}-?/, "").split("-").reject { |s| s.length < 3 }
  name_parts = p.name.downcase.gsub("nobile", "").gsub(/\d{4}/, "").split(/\s+/).reject { |s| s.length < 3 }
  keys = (slug_parts + name_parts).map(&:strip).uniq
  keys.each { |k| product_index[k] ||= []; product_index[k] << p }
  product_index[p.slug] = [p]
end

# Group blobs by filename prefix (first image per product = position 1)
# e.g. nobile_kiteboard_nhp_carbon_2026_1.webp, _2.webp, etc.
blob_groups = Hash.new { |h, k| h[k] = [] }
unattached_blobs.each do |blob|
  fname = blob.filename.to_s.downcase
  # Remove trailing _N (position number) to get base key
  base = fname.sub(/_\d+\.\w+$/, "").sub(/\.\w+$/, "")
  blob_groups[base] << blob
end

attached = 0
skipped  = 0

blob_groups.each do |base_key, blobs|
  # Sort so _1 comes first
  blobs.sort_by! { |b| b.filename.to_s }

  # Find matching product
  matched_product = nil

  # Try progressively shorter key segments
  words = base_key.split("_").reject { |w| w.length < 3 || w =~ /^\d{4}$/ || %w[kiteboard kiteboarding nobile].include?(w) }

  words.combination(2).each do |combo|
    key = combo.join("_")
    if product_index[key]
      matched_product = product_index[key].first
      break
    end
  end

  # Fallback: single word match
  if matched_product.nil?
    words.each do |w|
      next if w.length < 4
      if product_index[w]
        matched_product = product_index[w].first
        break
      end
    end
  end

  unless matched_product
    puts "  ❓ No match for: #{base_key} (#{blobs.size} blobs)"
    skipped += 1
    next
  end

  master = matched_product.master
  puts "  📎 #{matched_product.name} ← #{blobs.first.filename} (+#{blobs.size - 1} more)"

  blobs.each_with_index do |blob, i|
    img = Spree::Image.new(
      viewable:  master,
      alt:       matched_product.name,
      position:  i + 1
    )
    img.type = "Spree::Image"
    img.attachment.attach(blob)
    img.save!
    attached += 1
  end
end

puts ""
puts "Attached: #{attached} images across products"
puts "No match: #{skipped} blob groups"
puts "Done: #{Time.current}"
