#!/usr/bin/env ruby
# frozen_string_literal: true
# Universal sheet image re-importer.
# Logic:
#   1. Find all products in DB whose variants match EANs from the sheet
#   2. DELETE existing images ONLY on those matched products
#   3. Re-import fresh images from the sheet
#   4. Products NOT found in sheet → images untouched
#
# Usage:
#   SHEET=cabrinha      bundle exec rails runner /rails/tmp/reimport_by_ean.rb
#   SHEET=ion           bundle exec rails runner /rails/tmp/reimport_by_ean.rb
#   SHEET=tabou_gaastra bundle exec rails runner /rails/tmp/reimport_by_ean.rb

require 'csv'
require 'net/http'
require 'open-uri'

SHEETS = {
  "cabrinha" => {
    url:           'https://docs.google.com/spreadsheets/d/1nk-NW2QXQo6uTGr00AJ2q62svZS_q3muS7_SKQVZc_s/export?format=csv',
    ean_col:       'EAN/UPC',
    name_col:      'product name',
    img_cols:      (1..6).map { |i| "Image direct link #{i}" },
    master_only:   true,   # all images → master variant
  },
  "ion" => {
    url:           'https://docs.google.com/spreadsheets/d/1I0HNNCyuTl1PJFV-3n5kn6Fz6Bk-02BFz7nlB4hjIHg/export?format=csv&gid=236144958',
    ean_col:       'Variant Barcode',
    name_col:      'Title',
    img_src_col:   'Image Src',       # → master variant
    variant_col:   'Variant Image',   # → specific variant (by EAN)
    master_only:   false,
  },
  "ion_full" => {
    url:           'https://docs.google.com/spreadsheets/d/1eo5WMuZzw6sM_4b40lOf6Dlw6IT0v59RU61xnyxbRz0/export?format=csv',
    ean_col:       'Variant Barcode',
    name_col:      'Title',
    img_src_col:   'Image Src',
    variant_col:   'Variant Image',
    master_only:   false,
  },
  "tabou_gaastra" => {
    url:           'https://docs.google.com/spreadsheets/d/1WQpNTIi5xcZi4pmjZoaokliFEmwxiKLCJvLdSXp3bC4/export?format=csv',
    ean_col:       'GTIN',
    name_col:      'ItemName',
    img_cols:      (0..6).map { |i| "ImageURLpng#{i}" },
    master_only:   true,  # all images → master variant
  },
}.freeze

sheet_key = ENV.fetch('SHEET', 'cabrinha').downcase
config    = SHEETS[sheet_key] or raise "Unknown SHEET=#{sheet_key}. Use: #{SHEETS.keys.join(', ')}"

puts "╔══════════════════════════════════════════╗"
puts "║  EAN-matched image re-import             ║"
puts "║  Sheet: #{sheet_key.ljust(32)} ║"
puts "╚══════════════════════════════════════════╝"
puts ""

# ── STEP 1: Download CSV ──────────────────────────────────────
puts "STEP 1: Downloading CSV..."
csv_path = "/rails/tmp/reimport_#{sheet_key}.csv"
unless File.exist?(csv_path)
  File.write(csv_path, URI.open(config[:url], "User-Agent" => "Mozilla/5.0", read_timeout: 60).read)
end
puts "  #{File.readlines(csv_path).count} rows"

# ── STEP 2: Parse CSV → EAN → image URLs ─────────────────────
puts "\nSTEP 2: Parsing sheet..."

# For Cabrinha-style (one image set per product/EAN):
#   ean → { name, images: [] }
# For ION-style (master image on first row of handle, variant image per row):
#   ean → { name, master_url, variant_url }
ean_data    = {}   # ean → { name:, master_url:, variant_url: OR images: }
handle_seen = {}   # handle → first Image Src (for ION master image)

CSV.foreach(csv_path, headers: true, liberal_parsing: true) do |row|
  ean  = row[config[:ean_col]].to_s.strip
  name = row[config[:name_col]].to_s.strip
  next if ean.blank?

  if config[:master_only]
    # Cabrinha: collect direct link images
    imgs = config[:img_cols].map { |c| row[c].to_s.strip }.select { |u| u.start_with?("http") }
    ean_data[ean] ||= { name: name, images: imgs } unless imgs.empty?
  else
    # ION: Image Src (master) + Variant Image (per variant)
    handle        = row["Handle"].to_s.strip
    image_src     = row[config[:img_src_col]].to_s.strip
    variant_image = row[config[:variant_col]].to_s.strip

    # Track first Image Src per handle as master image
    handle_seen[handle] ||= image_src if image_src.start_with?("http")

    ean_data[ean] = {
      name:        name,
      master_url:  handle_seen[handle],
      variant_url: variant_image.start_with?("http") ? variant_image : nil,
    }
  end
end

puts "  EANs with image data: #{ean_data.size}"

# ── STEP 3: Match EANs → Spree variants ──────────────────────
puts "\nSTEP 3: Matching EANs to Spree variants..."

# Load ALL variants with barcodes
variant_by_barcode      = {}  # barcode → non-master preferred
master_variant_by_barcode = {} # barcode → master variant

Spree::Variant.where.not(barcode: [nil, ""]).find_each do |v|
  bc = v.barcode.to_s.strip
  next if bc.blank?
  if v.is_master?
    master_variant_by_barcode[bc] = v
  else
    variant_by_barcode[bc] = v
  end
end

# Collect all product_ids matched by sheet EANs
matched_product_ids = Set.new
ean_data.each_key do |ean|
  v = variant_by_barcode[ean] || master_variant_by_barcode[ean]
  matched_product_ids << v.product_id if v
end

puts "  Products matched by EAN: #{matched_product_ids.size}"

# ── STEP 4: Delete existing images on matched products ────────
puts "\nSTEP 4: Deleting existing images on #{matched_product_ids.size} matched products..."

if matched_product_ids.any?
  # Get all variant IDs for matched products
  variant_ids = Spree::Variant.where(product_id: matched_product_ids.to_a).pluck(:id)

  # Get image asset IDs
  image_ids = Spree::Image.where(viewable_type: 'Spree::Variant', viewable_id: variant_ids).pluck(:id)

  if image_ids.any?
    blob_ids = ActiveStorage::Attachment
      .where(record_type: 'Spree::Asset', record_id: image_ids)
      .pluck(:blob_id)

    ActiveStorage::VariantRecord.where(blob_id: blob_ids).delete_all
    ActiveStorage::Attachment.where(record_type: 'Spree::Asset', record_id: image_ids).delete_all
    Spree::Image.where(id: image_ids).delete_all

    puts "  Deleted #{image_ids.size} images from #{matched_product_ids.size} products"
  else
    puts "  No existing images to delete"
  end
end

# ── STEP 5: Download and attach images ───────────────────────
puts "\nSTEP 5: Importing images..."

def fetch_image(url)
  uri = URI.parse(url)
  response = Net::HTTP.start(uri.host, uri.port,
    use_ssl: uri.scheme == 'https', open_timeout: 15, read_timeout: 30
  ) { |h| h.get(uri.request_uri, 'User-Agent' => 'Mozilla/5.0') }
  raise "HTTP #{response.code}" unless response.is_a?(Net::HTTPSuccess)
  ext   = File.extname(uri.path).downcase.presence || ".jpg"
  ext   = ".jpg" unless %w[.jpg .jpeg .png .webp .gif].include?(ext)
  ct    = case ext
          when ".jpg", ".jpeg" then "image/jpeg"
          when ".webp"         then "image/webp"
          when ".gif"          then "image/gif"
          else "image/png"
          end
  [response.body, File.basename(uri.path).presence || "image#{ext}", ct]
end

def attach_image(viewable, url, alt:, position:)
  data, fname, ct = fetch_image(url)
  img = Spree::Image.new(viewable: viewable, alt: alt, position: position)
  img.type = 'Spree::Image'
  img.attachment.attach(io: StringIO.new(data), filename: fname, content_type: ct)
  img.save!
  true
rescue => e
  puts "    ❌ #{e.message.truncate(70)}"
  false
end

products_done = {}
imported = 0; skipped = 0; errors = 0

ean_data.each do |ean, data|
  non_master = variant_by_barcode[ean]
  master_v   = non_master ? Spree::Variant.find_by(product_id: non_master.product_id, is_master: true)
                           : master_variant_by_barcode[ean]
  unless master_v
    skipped += 1
    next
  end

  product_id = master_v.product_id

  if config[:master_only]
    # Cabrinha: only attach master images (shown in category)
    next if products_done[product_id]
    products_done[product_id] = true

    product_name = data[:name]
    puts "  📦 #{product_name}"
    data[:images].each_with_index do |url, i|
      ok = attach_image(master_v, url, alt: product_name, position: i + 1)
      ok ? (imported += 1; print "    ✅ img#{i+1}\n") : (errors += 1)
    end
  else
    # ION: master image (first per product) + variant-specific image
    unless products_done[product_id]
      products_done[product_id] = true
      if data[:master_url]
        ok = attach_image(master_v, data[:master_url], alt: data[:name], position: 1)
        ok ? (imported += 1) : (errors += 1)
      end
    end

    # Variant-specific image
    if data[:variant_url] && non_master
      full_non_master = Spree::Variant.find(non_master.id)
      alt = "#{data[:name]} #{full_non_master.options_text}".strip
      ok = attach_image(full_non_master, data[:variant_url], alt: alt, position: 1)
      ok ? (imported += 1) : (errors += 1)
    end
  end
end

puts ""
puts "╔════════════════════════════════╗"
puts "║          DONE                  ║"
puts "╠════════════════════════════════╣"
puts "║ Products:  #{products_done.size.to_s.ljust(21)} ║"
puts "║ Imported:  #{imported.to_s.ljust(21)} ║"
puts "║ Skipped:   #{skipped.to_s.ljust(21)} ║"
puts "║ Errors:    #{errors.to_s.ljust(21)} ║"
puts "╚════════════════════════════════╝"
puts "Finished: #{Time.current}"
