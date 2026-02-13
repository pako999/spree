# NeilPryde / Cabrinha / JP Stock Sync Job
# Downloads stock CSV from NeilPryde FTP and updates Spree variant stock items.
# Scheduled via Solid Queue recurring jobs (config/recurring.yml) — every 6 hours.
#
# FTP: ftp://mail.neilpryde.de/Reseller/stockinfo/stockinfo_summer_csv.csv
# Format: semicolon-separated CSV with header row
# Columns: Productarea;Productgroup;Articlenr;Articledescription;Articledescription2;
#           Colour;Size;Article season;EAN;UPC;Availability;Available Quantity;EAN/UPC
#
# Matching: EAN (col 8) preferred, falls back to UPC (col 9) → Spree::Variant.barcode
# NeilPryde/JP items have EAN codes, Cabrinha items typically only have UPC codes.

require "open3"

class SyncPrydeStockJob < ApplicationJob
  queue_as :default

  FTP_HOST     = "mail.neilpryde.de"
  FTP_USER     = "haendler"
  FTP_PASSWORD = "welcome"
  FTP_PATH     = "Reseller/stockinfo/stockinfo_summer_csv.csv"

  # Only sync these product areas (brands)
  SYNC_BRANDS = [
    "Neil Pryde", "Neil Pryde Foil", "Neil Pryde Wing", "NP",
    "Cabrinha",
    "JP", "JP SUP", "JP Wingboard"
  ].freeze

  def perform
    Rails.logger.info "[PrydeStock] Starting NeilPryde/Cabrinha/JP stock sync..."

    # Step 1: Download stock CSV from FTP
    csv_data, status = Open3.capture2(
      "curl", "-s", "--connect-timeout", "30",
      "ftp://#{FTP_USER}:#{FTP_PASSWORD}@#{FTP_HOST}/#{FTP_PATH}"
    )

    unless status.success?
      Rails.logger.error "[PrydeStock] FTP download failed!"
      return
    end

    Rails.logger.info "[PrydeStock] Downloaded #{csv_data.bytesize} bytes from FTP"

    # Force encoding — FTP file uses Latin-1 (German umlauts)
    csv_data = csv_data.force_encoding("ISO-8859-1").encode("UTF-8", invalid: :replace, undef: :replace)

    Rails.logger.info "[PrydeStock] Parsed #{csv_data.lines.count} lines"

    # Step 2: Parse CSV into barcode → quantity hash (skip header row)
    stock_map = {}
    first_line = true

    csv_data.each_line do |line|
      # Skip header
      if first_line
        first_line = false
        next
      end

      line = line.strip
      next if line.empty?

      parts = line.split(";")
      next if parts.length < 13

      brand = parts[0].strip
      ean   = parts[8].strip   # EAN code (NeilPryde/JP have this)
      upc   = parts[9].strip   # UPC code (Cabrinha uses this)
      qty   = parts[11].strip.to_i  # Available Quantity

      # Filter to only our brands
      next unless SYNC_BRANDS.include?(brand)

      # Prefer EAN, fall back to UPC — both match to Spree barcode field
      code = ean.present? ? ean : upc
      next if code.blank?

      stock_map[code] = qty
    end

    Rails.logger.info "[PrydeStock] Parsed #{stock_map.size} EAN entries (#{stock_map.count { |_, q| q > 0 }} with stock)"

    # Step 3: Match EANs to Spree variants and update stock
    stock_location = Spree::StockLocation.first
    unless stock_location
      Rails.logger.error "[PrydeStock] No stock location found!"
      return
    end

    matched = 0
    updated = 0
    skipped = 0

    # Get all variants with matching barcodes in one query
    variants_with_barcodes = Spree::Variant.where(barcode: stock_map.keys).includes(:stock_items)
    variant_map = variants_with_barcodes.index_by(&:barcode)

    Rails.logger.info "[PrydeStock] Matched #{variant_map.size} of #{stock_map.size} EANs to variants"

    stock_map.each do |ean, new_qty|
      variant = variant_map[ean]
      next unless variant
      matched += 1

      stock_item = variant.stock_items.find_by(stock_location_id: stock_location.id)

      if stock_item
        old_qty = stock_item.count_on_hand
        if old_qty != new_qty
          stock_item.set_count_on_hand(new_qty)
          updated += 1
        else
          skipped += 1
        end
      else
        stock_location.stock_items.create!(variant: variant, count_on_hand: new_qty, backorderable: false)
        updated += 1
      end
    end

    Rails.logger.info "[PrydeStock] Sync complete — Matched: #{matched}, Updated: #{updated}, Unchanged: #{skipped}, Unmatched: #{stock_map.size - matched}"
  end
end
