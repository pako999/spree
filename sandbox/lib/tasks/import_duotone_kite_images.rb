#!/usr/bin/env ruby
# frozen_string_literal: true
# =============================================================================
# Import missing Duotone Kiteboarding images from Shopify-format Google Sheet.
# Only processes products that currently have 0 images (safe to re-run).
#
# Run: SHEET_ID=YOUR_SHEET_ID docker exec surf-store bundle exec rails runner /rails/tmp/import_duotone_kite_images.rb
# Or:  docker exec surf-store bundle exec rails runner /rails/tmp/import_duotone_kite_images.rb
# =============================================================================

require 'csv'
require 'open-uri'
require 'set'
require 'logger'

LOG = Logger.new($stdout)
LOG.formatter = proc { |_, _, _, msg| "#{msg}\n" }

# ── CONFIG: set your sheet ID here or pass via SHEET_ID env var ──────────────
SHEET_ID = ENV.fetch('SHEET_ID', 'REPLACE_WITH_DUOTONE_KITEBOARDING_SHEET_ID')
SHEET_URL = "https://docs.google.com/spreadsheets/d/#{SHEET_ID}/export?format=csv"

LOG.info "=== Duotone Kiteboarding Image Import ==="
LOG.info "Sheet: #{SHEET_URL}"
LOG.info ""

# ── Download CSV ──────────────────────────────────────────────────────────────
LOG.info "Downloading CSV..."
csv_data = URI.open(
  SHEET_URL,
  "User-Agent" => "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)",
  read_timeout: 60,
  open_timeout: 15
).read
LOG.info "  Downloaded #{csv_data.bytesize} bytes"

# ── Build variant lookups ─────────────────────────────────────────────────────
LOG.info "Building variant lookups..."
variants_by_barcode = {}
Spree::Variant.where(is_master: false).where.not(barcode: [nil, ""]).find_each do |v|
  variants_by_barcode[v.barcode.to_s.strip] = v
end

masters_by_product_id = {}
master_by_barcode     = {}
Spree::Variant.where(is_master: true).find_each do |v|
  masters_by_product_id[v.product_id] = v
  master_by_barcode[v.barcode.to_s.strip] = v if v.barcode.present?
end

LOG.info "  Non-master variants with barcodes: #{variants_by_barcode.size}"
LOG.info "  Master variants: #{masters_by_product_id.size}"
LOG.info ""

# ── Image download helper ─────────────────────────────────────────────────────
def download_image(url)
  uri = URI.parse(url)
  data = URI.open(
    uri,
    "User-Agent" => "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)",
    read_timeout: 30,
    open_timeout: 15
  ).read
  ext = File.extname(uri.path).downcase.presence || ".jpg"
  ext = ".jpg" unless %w[.jpg .jpeg .png .webp .gif].include?(ext)
  content_type = case ext
                 when ".jpg", ".jpeg" then "image/jpeg"
                 when ".webp"         then "image/webp"
                 when ".gif"          then "image/gif"
                 else "image/png"
                 end
  fname = File.basename(uri.path).presence || "image#{ext}"
  [data, fname, content_type]
rescue => e
  raise "Download failed: #{e.message.truncate(100)}"
end

def attach_image(viewable, url, alt:, position: 1)
  data, fname, content_type = download_image(url)
  img = Spree::Image.new(viewable: viewable, alt: alt, position: position)
  img.attachment.attach(io: StringIO.new(data), filename: fname, content_type: content_type)
  img.save!
  true
rescue => e
  LOG.error "  ❌ #{e.message.truncate(120)}"
  false
end

# ── Process CSV ───────────────────────────────────────────────────────────────
LOG.info "Processing CSV rows..."

# Track which product masters already have images (from DB before we start)
products_with_images = Set.new(
  Spree::Image
    .joins(viewable: :product)
    .where(viewable_type: 'Spree::Variant')
    .joins("INNER JOIN spree_variants sv ON sv.id = spree_assets.viewable_id AND sv.is_master = true")
    .pluck("sv.product_id")
)
LOG.info "  Products already with images (skip): #{products_with_images.size}"

handles_seen_for_master = Set.new
master_count  = 0
variant_count = 0
skip_count    = 0
error_count   = 0

CSV.parse(csv_data, headers: true, liberal_parsing: true) do |row|
  handle        = row["Handle"].to_s.strip
  barcode       = row["Variant Barcode"].to_s.strip
  image_src     = row["Image Src"].to_s.strip
  variant_image = row["Variant Image"].to_s.strip
  title         = row["Title"].to_s.strip

  # ── Master image (first Image Src per Handle) ──────────────────────────
  if image_src.start_with?("http") && !handles_seen_for_master.include?(handle)
    handles_seen_for_master.add(handle)

    product = Spree::Product.find_by(slug: handle) ||
              Spree::Product.find_by("LOWER(slug) = ?", handle.downcase)

    if product.nil? && barcode.present?
      v = variants_by_barcode[barcode] || master_by_barcode[barcode]
      product = v&.product
    end

    if product
      if products_with_images.include?(product.id)
        skip_count += 1
        next
      end

      master = masters_by_product_id[product.id]
      if master && attach_image(master, image_src, alt: title, position: 1)
        products_with_images.add(product.id) # don't add again
        master_count += 1
        print "M"
        $stdout.flush
      else
        error_count += 1
      end
    end
  end

  # ── Variant-specific image (Variant Image, matched by barcode) ──────────
  next unless variant_image.start_with?("http") && barcode.present?

  variant = variants_by_barcode[barcode] || master_by_barcode[barcode]
  next unless variant

  # Skip if this product already had images before we started
  next if products_with_images.include?(variant.product_id) && master_count == 0

  alt = [title, variant.options_text].reject(&:blank?).join(" ")
  if attach_image(variant, variant_image, alt: alt, position: 1)
    variant_count += 1
    print "v"
    $stdout.flush
  else
    error_count += 1
  end
end

puts ""
LOG.info ""
LOG.info "╔═══════════════════════════════════╗"
LOG.info "║   Duotone Kite Image Import Done  ║"
LOG.info "╠═══════════════════════════════════╣"
LOG.info "║ Master images added:   #{master_count.to_s.ljust(9)} ║"
LOG.info "║ Variant images added:  #{variant_count.to_s.ljust(9)} ║"
LOG.info "║ Products skipped:      #{skip_count.to_s.ljust(9)} ║"
LOG.info "║ Errors:                #{error_count.to_s.ljust(9)} ║"
LOG.info "╚═══════════════════════════════════╝"
