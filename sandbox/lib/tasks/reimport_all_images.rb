#!/usr/bin/env ruby
# frozen_string_literal: true
#
# Full image reset + re-import from all Shopify-format CSVs.
# Strategy:
#   1. Delete ALL existing Spree::Image records (+ blobs + attachments)
#   2. For each CSV: match Variant Barcode → Spree::Variant
#      - Image Src (first occurrence per Handle) → master variant
#      - Variant Image → the specific matched non-master variant
#
# Run: docker exec surf-store bundle exec rails runner /rails/tmp/reimport_all_images.rb

require 'csv'
require 'open-uri'
require 'set'

SHEET_URLS = {
  "ION Water Main"       => "https://docs.google.com/spreadsheets/d/1I0HNNCyuTl1PJFV-3n5kn6Fz6Bk-02BFz7nlB4hjIHg/export?format=csv&gid=236144958",
  "ION Full"             => "https://docs.google.com/spreadsheets/d/1eo5WMuZzw6sM_4b40lOf6Dlw6IT0v59RU61xnyxbRz0/export?format=csv",
  "Duotone Wing 2026"    => "https://docs.google.com/spreadsheets/d/1nK_RowVZP5KDYU1WKjIyJGeOPgVJm-uIspuXPcQjOS0/export?format=csv",
  "Duotone Wingfoil 2026"=> "https://docs.google.com/spreadsheets/d/1OXb4No4pzBs8hwbMB7q17jMV17HTV37Nl7kwagn2OjY/export?format=csv",
  "Duotone Windsurf DTW26"=>"https://docs.google.com/spreadsheets/d/1fNVzmPICVpOb6CnpqFMAT-s8VueeDyZajXL0r8Qf5RQ/export?format=csv",
  "Cabrinha"             => "https://docs.google.com/spreadsheets/d/1nk-NW2QXQo6uTGr00AJ2q62svZS_q3muS7_SKQVZc_s/export?format=csv",
}.freeze

LOG = Logger.new($stdout)
LOG.formatter = proc { |_, _, _, msg| "#{msg}\n" }

def download_image(url, timeout: 30)
  uri = URI.parse(url)
  data = URI.open(
    uri,
    "User-Agent" => "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)",
    read_timeout: timeout,
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
  raise "Download failed: #{e.message.truncate(80)}"
end

def attach_image(viewable, url, alt:, position: 1)
  data, fname, content_type = download_image(url)
  img = Spree::Image.new(viewable: viewable, alt: alt, position: position)
  img.attachment.attach(io: StringIO.new(data), filename: fname, content_type: content_type)
  img.save!
  true
rescue => e
  LOG.error("    ❌ #{e.message}")
  false
end

# ─────────────────────────────────────────────────────────
# STEP 1: Delete ALL existing images
# ─────────────────────────────────────────────────────────
LOG.info "=== STEP 1: Deleting all existing product images ==="

total_before = Spree::Image.count
LOG.info "  Images before: #{total_before}"

# Bulk delete via SQL (fast, no callbacks that trigger jobs)
attachment_ids = ActiveStorage::Attachment
  .joins("INNER JOIN spree_assets ON spree_assets.id = active_storage_attachments.record_id")
  .where("active_storage_attachments.record_type = 'Spree::Asset' AND spree_assets.type = 'Spree::Image'")
  .pluck(:blob_id)

# Delete in order: variant records → attachments → blobs → assets
ActiveStorage::VariantRecord.where(blob_id: attachment_ids).delete_all
ActiveStorage::Attachment
  .joins("INNER JOIN spree_assets ON spree_assets.id = active_storage_attachments.record_id")
  .where("active_storage_attachments.record_type = 'Spree::Asset' AND spree_assets.type = 'Spree::Image'")
  .delete_all
ActiveStorage::Blob.where(id: attachment_ids).delete_all
Spree::Image.delete_all

LOG.info "  ✅ Deleted #{total_before} images"
LOG.info ""

# ─────────────────────────────────────────────────────────
# STEP 2: Build variant lookup (barcode → variant)
# ─────────────────────────────────────────────────────────
LOG.info "=== STEP 2: Loading Spree variants ==="

# non-master variants by barcode
variants_by_barcode = {}
Spree::Variant.where(is_master: false).where.not(barcode: [nil, ""]).find_each do |v|
  variants_by_barcode[v.barcode.to_s.strip] = v
end

# master variants by product slug/handle
masters_by_product_id = {}
Spree::Variant.where(is_master: true).find_each do |v|
  masters_by_product_id[v.product_id] = v
end

# lookup master by barcode too (for products that have no non-master variants)
master_by_barcode = {}
Spree::Variant.where(is_master: true).where.not(barcode: [nil, ""]).find_each do |v|
  master_by_barcode[v.barcode.to_s.strip] = v
end

LOG.info "  Non-master variants with barcodes: #{variants_by_barcode.size}"
LOG.info "  Master variants: #{masters_by_product_id.size}"
LOG.info ""

# ─────────────────────────────────────────────────────────
# STEP 3: Process each sheet
# ─────────────────────────────────────────────────────────
total_master_imgs  = 0
total_variant_imgs = 0
total_errors       = 0

SHEET_URLS.each do |sheet_name, url|
  LOG.info "=== Sheet: #{sheet_name} ==="

  # Download CSV
  begin
    csv_data = URI.open(url, "User-Agent" => "Mozilla/5.0", read_timeout: 60).read
  rescue => e
    LOG.error "  ❌ Failed to download: #{e.message}"
    next
  end

  # Parse rows, group by Handle
  # Each Handle = one product. First row with Image Src = master image.
  # Each row with Variant Barcode + Variant Image = variant-specific image.
  handles_seen_for_master = Set.new
  master_img_count  = 0
  variant_img_count = 0
  err_count         = 0

  begin
    CSV.parse(csv_data, headers: true, liberal_parsing: true) do |row|
      handle        = row["Handle"].to_s.strip
      barcode       = row["Variant Barcode"].to_s.strip
      image_src     = row["Image Src"].to_s.strip
      variant_image = row["Variant Image"].to_s.strip
      title         = row["Title"].to_s.strip

      # ── Master image (Image Src, first occurrence per Handle) ──
      if image_src.start_with?("http") && !handles_seen_for_master.include?(handle)
        handles_seen_for_master.add(handle)

        # Find product by matching a variant's barcode to this handle's rows
        # Best approach: match handle to product via slug
        product = Spree::Product.find_by(slug: handle) ||
                  Spree::Product.find_by("LOWER(slug) = ?", handle.downcase)

        if product.nil? && barcode.present?
          # Fallback: find via barcode → variant → product
          v = variants_by_barcode[barcode] || master_by_barcode[barcode]
          product = v&.product
        end

        if product
          master = masters_by_product_id[product.id]
          if master && attach_image(master, image_src, alt: title, position: 1)
            master_img_count += 1
            print "M"
          else
            err_count += 1
          end
        end
      end

      # ── Variant-specific image (Variant Image, matched by barcode) ──
      next unless variant_image.start_with?("http") && barcode.present?

      variant = variants_by_barcode[barcode]
      if variant.nil?
        # Might be a single-variant product — use master
        variant = master_by_barcode[barcode]
      end

      next unless variant

      alt = [title, variant.options_text].reject(&:blank?).join(" ")
      if attach_image(variant, variant_image, alt: alt, position: 1)
        variant_img_count += 1
        print "v"
      else
        err_count += 1
      end
    end
  rescue CSV::MalformedCSVError => e
    LOG.error "  ❌ CSV parse error: #{e.message}"
    next
  end

  STDOUT.flush
  LOG.info ""
  LOG.info "  Master images:  #{master_img_count}"
  LOG.info "  Variant images: #{variant_img_count}"
  LOG.info "  Errors:         #{err_count}"
  LOG.info ""

  total_master_imgs  += master_img_count
  total_variant_imgs += variant_img_count
  total_errors       += err_count
end

LOG.info "╔══════════════════════════════════╗"
LOG.info "║         FINAL SUMMARY            ║"
LOG.info "╠══════════════════════════════════╣"
LOG.info "║ Master images imported:   #{total_master_imgs.to_s.ljust(6)} ║"
LOG.info "║ Variant images imported:  #{total_variant_imgs.to_s.ljust(6)} ║"
LOG.info "║ Total errors:             #{total_errors.to_s.ljust(6)} ║"
LOG.info "╚══════════════════════════════════╝"
LOG.info "Finished: #{Time.current}"
