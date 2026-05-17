#!/usr/bin/env ruby
# frozen_string_literal: true
# FIX 1: Copy first variant image blob to master for products missing master image.
# FIX 2: Attach orphaned Cabrinha blobs to matching products by filename.
#
# Run: bundle exec rails runner /rails/tmp/fix_collection_and_cabrinha.rb

puts "=" * 55
puts "FIX 1: Promote variant images → master (collection fix)"
puts "=" * 55

fixed1 = 0; skip1 = 0

# Find products: has non-master variant image, but no master image
product_ids_with_variant_img = ActiveRecord::Base.connection.execute("
  SELECT DISTINCT nv.product_id
  FROM spree_variants nv
  JOIN spree_assets sa ON sa.viewable_id = nv.id
    AND sa.viewable_type = 'Spree::Variant' AND sa.type = 'Spree::Image'
  WHERE nv.is_master = FALSE
").pluck("product_id")

product_ids_with_master_img = ActiveRecord::Base.connection.execute("
  SELECT DISTINCT mv.product_id
  FROM spree_variants mv
  JOIN spree_assets ma ON ma.viewable_id = mv.id
    AND ma.viewable_type = 'Spree::Variant' AND ma.type = 'Spree::Image'
  WHERE mv.is_master = TRUE
").pluck("product_id")

needs_fix = product_ids_with_variant_img - product_ids_with_master_img
puts "Products needing fix: #{needs_fix.size}"

needs_fix.each do |product_id|
  product = Spree::Product.find_by(id: product_id)
  next unless product

  master = Spree::Variant.find_by(product_id: product_id, is_master: true)
  next unless master

  # Get first variant image asset
  variant_ids = Spree::Variant.where(product_id: product_id, is_master: false).pluck(:id)
  first_img = Spree::Image
    .where(viewable_type: 'Spree::Variant', viewable_id: variant_ids)
    .order(:position)
    .first

  unless first_img&.attachment&.attached?
    skip1 += 1; next
  end

  blob = first_img.attachment.blob
  key  = blob.key
  path = Rails.root.join("storage", key[0, 2], key[2, 2], key)

  unless File.exist?(path)
    skip1 += 1; next
  end

  begin
    new_img = Spree::Image.new(viewable: master, alt: product.name, position: 1)
    new_img.type = 'Spree::Image'
    new_img.attachment.attach(blob)
    new_img.save!
    puts "  ✅ #{product.name}"
    fixed1 += 1
  rescue => e
    puts "  ❌ #{product.name}: #{e.message.truncate(60)}"
    skip1 += 1
  end
end

puts "FIX 1 done — Fixed: #{fixed1} | Skipped: #{skip1}"
puts ""

puts "=" * 55
puts "FIX 2: Attach orphaned Cabrinha blobs to products"
puts "=" * 55

# Get all unattached Cabrinha image blobs
orphan_blobs = ActiveStorage::Blob
  .left_joins(:attachments)
  .where(active_storage_attachments: { id: nil })
  .where("content_type LIKE 'image/%' AND byte_size > 5000")
  .where("LOWER(filename) LIKE '%cab-%' OR LOWER(filename) LIKE '%cabrinha%'")
  .to_a

puts "Orphaned Cabrinha blobs: #{orphan_blobs.size}"

# Build product lookup by name fragment → product
cabrinha_products = Spree::Product
  .where("name ILIKE '%cabrinha%'")
  .where(deleted_at: nil)
  .includes(:master)

# Index by slug-style key
product_by_key = {}
cabrinha_products.each do |p|
  # Make slug-like key from name: "Cabrinha Mantis 2025" → "mantis"
  words = p.name.downcase
    .gsub("cabrinha", "")
    .gsub(/20\d\d/, "")
    .split(/[\s\-_.]+/)
    .map(&:strip)
    .reject { |w| w.length < 3 || %w[cab the and for].include?(w) }

  words.each { |w| product_by_key[w] ||= p }
  # Also full slug key
  slug_key = words.first(2).join("_")
  product_by_key[slug_key] = p if slug_key.present?
end

attached2 = 0; skip2 = 0; no_match = 0

# Group blobs by filename base (strip _1, _2 suffixes)
blob_groups = Hash.new { |h, k| h[k] = [] }
orphan_blobs.each do |blob|
  fname = blob.filename.to_s.downcase
  # Extract meaningful part: cab-mantis-351154-c11 → mantis
  base = fname
    .sub(/\.web[p]$|\.jpe?g$|\.png$/i, "")
    .sub(/^cab-?/, "")
    .gsub(/-\d+$/, "")              # remove trailing -1, -2
    .gsub(/-[0-9a-f]{8}-[0-9a-f-]+$/, "")  # remove UUID
    .split("-").first(2).join("_")  # take first 2 words
  blob_groups[base] << blob
end

blob_groups.each do |base_key, blobs|
  blobs.sort_by! { |b| b.filename.to_s }

  # Find matching product
  product = product_by_key[base_key]

  # Try single-word fallback
  if product.nil?
    base_key.split("_").each do |word|
      next if word.length < 4
      product = product_by_key[word]
      break if product
    end
  end

  unless product
    no_match += 1
    next
  end

  master = product.master

  # Skip if already has master image
  if Spree::Image.where(viewable_type: 'Spree::Variant', viewable_id: master.id).exists?
    skip2 += 1
    next
  end

  existing_count = Spree::Image.where(viewable_type: 'Spree::Variant', viewable_id: master.id).count

  blobs.each_with_index do |blob, i|
    key  = blob.key
    path = Rails.root.join("storage", key[0, 2], key[2, 2], key)
    next unless File.exist?(path)

    begin
      img = Spree::Image.new(viewable: master, alt: product.name, position: existing_count + i + 1)
      img.type = 'Spree::Image'
      img.attachment.attach(blob)
      img.save!
      attached2 += 1
    rescue => e
      puts "  ❌ #{blob.filename}: #{e.message.truncate(60)}"
    end
  end

  puts "  ✅ #{product.name} ← #{blobs.size} orphan blob(s)"
end

puts "FIX 2 done — Attached: #{attached2} | Skipped: #{skip2} | No match: #{no_match}"
puts ""
puts "Total summary:"
puts "  Collection fix (master promoted): #{fixed1}"
puts "  Cabrinha orphan blobs attached:   #{attached2}"
puts "Finished: #{Time.current}"
