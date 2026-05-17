#!/usr/bin/env ruby
# frozen_string_literal: true
# Pass 2: attach remaining Nobile images using explicit slug→blob keyword map
# Run: bundle exec rails runner /rails/tmp/attach_nobile_images2.rb

puts "=== Nobile image attachment - Pass 2 ==="

# Explicit mapping: product slug keyword → blob filename keywords
# Format: [slug_keyword, [blob_keywords_to_match]]
MAPPINGS = [
  ["nobile-2026-nhp",           ["nhp",        "NHP"]],         # NHP basic (not carbon, not split, not wmn)
  ["nobile-2026-nhp-carbon",    ["nhp_carbon", "NHP_CARBON", "nhp-carbon"]],
  ["nobile-nhp-carbon-split-2026", ["nhp_spli_carbon", "NHP_SPLI_CARBON", "splitcover_nhp"]],
  ["nobile-2026-nhp-split",     ["nhp_split",  "NHP_SPLIT", "NT5_SPLIT"]],
  ["nobile-2026-nhp-wmn",       ["nhp_wmn",    "nhp_whn",   "NHP_WHN", "NHP_WMN"]],
  ["nobile-2026-nt5",           ["nt5",        "NT5"]],
  ["nobile-nt5-split-2026",     ["nt5_split",  "NT5_SPLIT"]],
  ["nobile-the-horizon",        ["horizon",    "nobilehorizonv1"]],   # matches all sizes
  ["nobile-the-one",            ["the_one",    "the-one"]],
  ["nobile-ifs-nano",           ["ifs_nano",   "nano"]],
  ["nobile-fins",               ["fins",       "fin"]],
  ["nobile-clickngo",           ["click",      "ifs_click"]],
  ["nobile-backpack",           ["backpack"]],
  ["nobile-boardbag",           ["boardbag"]],
  ["nobile-check-in-bag",       ["check_in"]],
  ["nobile-hoodie",             ["hoodie"]],
  ["nobile-t-shirt",            ["t_shirt", "t-shirt", "tshirt"]],
  ["nobile-trucker",            ["trucker"]],
  ["nobile-bucket",             ["bucket"]],
  ["nobile-wave-straps",        ["straps"]],
  ["nobile-pump",               ["pump"]],
].freeze

# Get all unattached Nobile blobs
unattached = ActiveStorage::Blob
  .left_joins(:attachments)
  .where(active_storage_attachments: { id: nil })
  .where("content_type LIKE 'image/%' AND byte_size > 1000")
  .where("LOWER(filename) LIKE '%nobile%' OR LOWER(filename) LIKE '%nhp%' OR
          LOWER(filename) LIKE '%nt5%' OR LOWER(filename) LIKE '%horizon%' OR
          LOWER(filename) LIKE '%carpet%' OR LOWER(filename) LIKE '%horizon%'")
  .to_a

puts "Unattached Nobile blobs: #{unattached.size}"

attached = 0
skipped_already = 0

MAPPINGS.each do |slug_key, keywords|
  # Find all products matching this slug key
  products = Spree::Product
    .where("slug LIKE ?", "%#{slug_key}%")
    .where(deleted_at: nil)
    .includes(:master)

  next if products.empty?

  # Find matching blobs
  matching_blobs = unattached.select do |b|
    fname = b.filename.to_s
    keywords.any? { |kw| fname.include?(kw) }
  end
  next if matching_blobs.empty?

  # Assign one blob per matching product (or all to the first if slug is unique)
  target_product = products.first
  master = target_product.master

  # Check if already has an image from pass 1
  existing_count = Spree::Image.where(viewable: master).count

  matching_blobs.sort_by { |b| b.filename.to_s }.each_with_index do |blob, i|
    img = Spree::Image.new(
      viewable: master,
      alt:      target_product.name,
      position: existing_count + i + 1
    )
    img.type = "Spree::Image"
    img.attachment.attach(blob)
    img.save!
    attached += 1
    unattached.delete(blob)  # remove so it's not reused
  end

  puts "  ✅ #{target_product.name} ← #{matching_blobs.size} images"
end

# Also handle HORIZON sizes (all sizes share similar images)
["The HORIZON 6 m", "The HORIZON 9 m", "The HORIZON 10 m",
 "The HORIZON 12 m", "The HORIZON 14 m"].each do |name|
  product = Spree::Product.find_by("name LIKE ?", "%#{name}%")
  next unless product
  master = product.master
  next if Spree::Image.where(viewable: master).exists?

  # Copy images from "The HORIZON 7.5 m" (the one that got matched)
  source = Spree::Product.find_by("name LIKE '%HORIZON 7.5%'")
  next unless source

  source_imgs = Spree::Image.where(viewable: source.master).includes(attachment_attachment: :blob)
  next if source_imgs.empty?

  source_imgs.first(3).each_with_index do |src_img, i|
    blob = src_img.attachment.blob
    img = Spree::Image.new(viewable: master, alt: product.name, position: i + 1)
    img.type = "Spree::Image"
    img.attachment.attach(blob)
    img.save!
    attached += 1
  end
  puts "  ✅ #{product.name} ← copied from HORIZON 7.5 source"
end

# Same for The ONE sizes
["The ONE 5m v2", "The ONE 10m v2", "The ONE 12m v2"].each do |name|
  product = Spree::Product.find_by("name LIKE ?", "%#{name}%")
  next unless product
  master = product.master
  next if Spree::Image.where(viewable: master).exists?

  source = Spree::Product.find_by("name LIKE '%ONE 7m%'") ||
           Spree::Product.find_by("name LIKE '%ONE 9m%'")
  next unless source

  source_imgs = Spree::Image.where(viewable: source.master).includes(attachment_attachment: :blob)
  source_imgs.first(2).each_with_index do |src_img, i|
    blob = src_img.attachment.blob
    img = Spree::Image.new(viewable: master, alt: product.name, position: i + 1)
    img.type = "Spree::Image"
    img.attachment.attach(blob)
    img.save!
    attached += 1
  end
  puts "  ✅ #{product.name} ← copied from ONE source"
end

puts ""
puts "Attached: #{attached} additional images"
puts "Done: #{Time.current}"
