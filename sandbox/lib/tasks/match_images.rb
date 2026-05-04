puts "=== Matching unattached blobs to products ==="

# Get unattached blobs with real filenames
unattached = ActiveStorage::Blob
  .left_joins(:attachments)
  .where(active_storage_attachments: { id: nil })
  .where("content_type LIKE ? AND filename NOT LIKE ?", "image/%", "recovered_%")
  .where("byte_size > 5000")
  .to_a

puts "Unattached blobs with real filenames: #{unattached.size}"

# Get products without master images  
missing_products = Spree::Product.published
  .joins(:master)
  .left_joins(master: :images)
  .where(spree_assets: { id: nil })
  .includes(:master, master: :option_values)
  .to_a

puts "Products needing images: #{missing_products.size}"

# Build product lookup by SKU, name fragments, and slug
product_by_sku = {}
product_by_slug = {}
missing_products.each do |p|
  sku = p.master.sku.to_s.downcase.strip
  product_by_sku[sku] = p if sku.present?
  product_by_slug[p.slug] = p
  # Also index variant SKUs
  p.variants.each do |v|
    vsku = v.sku.to_s.downcase.strip
    product_by_sku[vsku] = p if vsku.present?
  end
end

matched = 0
assigned = 0

# For each unattached blob, try to match by filename
unattached.each do |blob|
  fname = blob.filename.to_s.downcase
  
  matched_product = nil
  
  # Try matching by SKU in filename
  product_by_sku.each do |sku, product|
    next if sku.length < 4
    if fname.include?(sku.gsub(/[-_]/, "")) || fname.include?(sku)
      matched_product = product
      break
    end
  end
  
  # Try matching by slug fragments
  unless matched_product
    product_by_slug.each do |slug, product|
      # Convert slug to filename-friendly patterns
      slug_parts = slug.split("-").reject { |p| p.length < 4 || %w[2025 2026 the and for].include?(p) }
      next if slug_parts.size < 2
      
      # Check if at least 3 significant parts of slug appear in filename
      matches = slug_parts.count { |part| fname.include?(part) }
      if matches >= [3, slug_parts.size * 0.6].min
        matched_product = product
        break
      end
    end
  end
  
  next unless matched_product
  matched += 1
  
  # Assign this blob to the product's master variant
  begin
    image = Spree::Image.new(
      viewable_type: "Spree::Variant",
      viewable_id: matched_product.master.id,
      position: matched_product.master.images.count + 1
    )
    image.save!(validate: false)
    
    ActiveStorage::Attachment.create!(
      name: "attachment",
      record_type: "Spree::Asset",
      record_id: image.id,
      blob_id: blob.id
    )
    
    assigned += 1
    puts "  ✅ #{matched_product.name} <- #{blob.filename}" if assigned <= 30
  rescue => e
    puts "  ❌ #{matched_product.name}: #{e.message}" if assigned < 50
  end
end

puts "\n=== Results ==="
puts "Matched: #{matched}"
puts "Assigned: #{assigned}"

still_missing = Spree::Product.published
  .left_joins(master: :images)
  .where(spree_assets: { id: nil })
  .count
puts "Products still missing images: #{still_missing}"
puts "Total images now: #{Spree::Image.count}"
