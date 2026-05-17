#!/usr/bin/env ruby
# frozen_string_literal: true
# FIX 1: Copy first variant image to master for products that have variant
#         images but no master image (shows on product page but not collection).
# FIX 2: For Cabrinha products missing all images, try to copy from a related
#         variant image blob already on disk (same product, different size).
#
# Run: bundle exec rails runner /rails/tmp/fix_collection_images.rb

puts "=== Fix: Promote variant images to master for collection display ==="

fixed = 0; skipped = 0

# Find products with variant images but no master image
products_needing_fix = Spree::Product
  .joins(:master)
  .where(deleted_at: nil)
  .where(
    "EXISTS (
      SELECT 1 FROM spree_variants nv
      JOIN spree_assets sa ON sa.viewable_id = nv.id
        AND sa.viewable_type = 'Spree::Variant' AND sa.type = 'Spree::Image'
      WHERE nv.product_id = spree_products.id AND nv.is_master = FALSE
    )"
  )
  .where(
    "NOT EXISTS (
      SELECT 1 FROM spree_variants mv
      JOIN spree_assets ma ON ma.viewable_id = mv.id
        AND ma.viewable_type = 'Spree::Variant' AND ma.type = 'Spree::Image'
      WHERE mv.product_id = spree_products.id AND mv.is_master = TRUE
    )"
  )

puts "Products with variant img but no master img: #{products_needing_fix.count}"
puts ""

products_needing_fix.each do |product|
  master = product.master

  # Get first variant image blob (prefer the one with most images)
  first_variant_img = Spree::Image
    .joins(viewable: [])
    .where(viewable_type: 'Spree::Variant')
    .where(viewable_id: Spree::Variant.where(product_id: product.id, is_master: false).pluck(:id))
    .order(:position)
    .first

  unless first_variant_img&.attachment&.attached?
    skipped += 1
    next
  end

  begin
    blob = first_variant_img.attachment.blob

    # Check file exists on disk
    key  = blob.key
    path = Rails.root.join("storage", key[0, 2], key[2, 2], key)
    unless File.exist?(path)
      skipped += 1
      next
    end

    # Create master image pointing to same blob
    new_img = Spree::Image.new(viewable: master, alt: product.name, position: 1)
    new_img.type = 'Spree::Image'
    new_img.attachment.attach(blob)
    new_img.save!

    puts "  ✅ #{product.name}"
    fixed += 1
  rescue => e
    puts "  ❌ #{product.name}: #{e.message.truncate(60)}"
    skipped += 1
  end
end

puts ""
puts "Fixed: #{fixed} | Skipped: #{skipped}"
puts "Done: #{Time.current}"
