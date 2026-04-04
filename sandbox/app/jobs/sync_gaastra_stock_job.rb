# Gaastra / Tabou Stock Sync Job
# Downloads stock CSV from Gaastra ConnectShop over HTTPS and updates Spree variant stock items.
# Scheduled via Solid Queue recurring jobs (config/recurring.yml) — every 3 hours.
#
# URL: https://connectshop.gaastra.io/nsstock/ns_shop_in_shop_stocklevel.csv
# Auth: HTTP Basic
# Format: tab-separated, no header row
# Columns: SKU \t EAN \t Product Name \t Quantity
#
# Matching: EAN (col 1, 0-indexed) → Spree::Variant#barcode
# Rows with blank EAN are skipped.

require "open3"

class SyncGaastraStockJob < ApplicationJob
  queue_as :default

  CSV_URL  = "https://connectshop.gaastra.io/nsstock/ns_shop_in_shop_stocklevel.csv"
  HTTP_USER = "Amodor10574"
  HTTP_PASS = "L78fchFJDKUa&V"
  STOCK_LOCATION_NAME = "Gaatra - Tabou"

  def perform
    Rails.logger.info "[GaastraStock] Starting Gaastra/Tabou stock sync..."

    # Step 1: Download CSV via HTTPS with Basic Auth
    csv_data, status = Open3.capture2(
      "curl", "-s", "--connect-timeout", "30",
      "-u", "#{HTTP_USER}:#{HTTP_PASS}",
      CSV_URL
    )

    unless status.success? && csv_data.present?
      Rails.logger.error "[GaastraStock] Download failed!"
      return
    end

    Rails.logger.info "[GaastraStock] Downloaded #{csv_data.lines.count} lines"

    # Step 2: Parse tab-separated CSV into EAN → quantity hash
    stock_map = {}
    csv_data.each_line do |line|
      line = line.strip
      next if line.empty?

      parts = line.split("\t")
      next if parts.length < 4

      ean = parts[1].strip
      qty = parts[3].strip.to_i

      next if ean.blank?

      stock_map[ean] = qty
    end

    Rails.logger.info "[GaastraStock] Parsed #{stock_map.size} EAN entries (#{stock_map.count { |_, q| q > 0 }} with stock)"

    # Step 3: Find the dedicated stock location
    stock_location = Spree::StockLocation.find_by(name: STOCK_LOCATION_NAME)
    unless stock_location
      Rails.logger.error "[GaastraStock] Stock location '#{STOCK_LOCATION_NAME}' not found!"
      return
    end

    # Step 4: Match EANs to Spree variants and update stock
    matched = 0
    updated = 0
    skipped = 0

    variants_with_barcodes = Spree::Variant.where(barcode: stock_map.keys).includes(:stock_items)
    variant_map = variants_with_barcodes.index_by(&:barcode)

    Rails.logger.info "[GaastraStock] Matched #{variant_map.size} of #{stock_map.size} EANs to variants"

    stock_map.each do |ean, new_qty|
      variant = variant_map[ean]
      next unless variant
      matched += 1

      stock_item = variant.stock_items.find { |si| si.stock_location_id == stock_location.id }

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

    Rails.logger.info "[GaastraStock] Sync complete — Matched: #{matched}, Updated: #{updated}, Unchanged: #{skipped}, Unmatched: #{stock_map.size - matched}"
  end
end
