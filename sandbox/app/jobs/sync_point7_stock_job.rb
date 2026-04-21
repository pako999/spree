# Point7 Stock Sync Job
# Downloads stock data from the Point7 export API and updates Spree variant stock items.
# Scheduled via Solid Queue recurring jobs (config/recurring.yml) — every 4 hours.
#
# API: https://point-7.com/wp-json/store/v1/export?token=cJs6kEAmWX6Kj2RfJuLBrPaf
# Format: CSV with header row
# Columns: category,name,type,sku,ean,ex sx3 preorder,sx3 single item,eu rrp,eu rrp +vat,inventory,image,description
#
# Matching: SKU (col 3) → Spree::Variant.sku (EAN col 4 is empty for most items)
# Stock location: "Point7" (id 5)

require "csv"
require "open3"

class SyncPoint7StockJob < SyncStockBaseJob

  API_URL = "https://point-7.com/wp-json/store/v1/export?token=cJs6kEAmWX6Kj2RfJuLBrPaf"

  def perform
    Rails.logger.info "[Point7Stock] Starting Point7 stock sync..."

    # Step 1: Download stock CSV from API
    csv_data, status = Open3.capture2(
      "curl", "-s", "--connect-timeout", "30",
      API_URL
    )

    unless status.success? && csv_data.present?
      raise "[Point7Stock] API download failed!"
    end

    Rails.logger.info "[Point7Stock] Downloaded #{csv_data.lines.count} lines from Point7 API"

    # Step 2: Parse CSV into SKU → quantity hash
    # Data rows may have leading whitespace — strip each line before parsing
    stock_map = {}
    first_line = true

    csv_data.each_line do |line|
      line = line.strip
      next if line.empty?

      # Skip header
      if first_line
        first_line = false
        next
      end

      begin
        row = CSV.parse_line(line)
        next unless row && row.length >= 10

        sku = row[3].to_s.strip
        qty = row[9].to_s.strip.to_i

        next if sku.blank?

        stock_map[sku] = qty
      rescue CSV::MalformedCSVError
        next
      end
    end

    Rails.logger.info "[Point7Stock] Parsed #{stock_map.size} SKU entries (#{stock_map.count { |_, q| q > 0 }} with stock)"

    # Step 3: Match SKUs to Spree variants and update stock
    stock_location = Spree::StockLocation.find_by(name: "Point7")
    unless stock_location
      raise "[Point7Stock] 'Point7' stock location not found!"
    end

    matched = 0
    updated = 0
    skipped = 0

    variants_with_skus = Spree::Variant.where(sku: stock_map.keys).includes(:stock_items)
    variant_map = variants_with_skus.index_by(&:sku)

    Rails.logger.info "[Point7Stock] Matched #{variant_map.size} of #{stock_map.size} SKUs to variants"

    stock_map.each do |sku, new_qty|
      variant = variant_map[sku]
      next unless variant
      matched += 1

      stock_item = variant.stock_items.find_by(stock_location_id: stock_location.id)

      if stock_item
        if stock_item.count_on_hand != new_qty
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

    report_sync_stats(matched: matched, updated: updated, skipped: skipped,
                      unmatched: stock_map.size - matched, total_in_feed: stock_map.size)
    Rails.logger.info "[Point7Stock] Sync complete — Matched: #{matched}, Updated: #{updated}, Unchanged: #{skipped}, Unmatched: #{stock_map.size - matched}"
  end
end
