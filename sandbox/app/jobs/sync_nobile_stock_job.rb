# Nobile Stock Sync Job
# Downloads stock CSV from a public Google Sheets export and updates Spree variant stock items.
# Scheduled via Solid Queue recurring jobs (config/recurring.yml).
#
# URL: Google Sheets published CSV (updated manually by Nobile team)
# Format: CSV with header row
# Columns (0-indexed):
#   0  = Handle
#   1  = Title
#   2  = Option1 Name
#   3  = Option1 Value
#   4  = Option2 Name
#   5  = Option2 Value
#   8  = SKU  ← match key
#   18 = On hand (new)  ← quantity to set
#
# Matching: SKU (col 8) → Spree::Variant#sku (prefer non-master)
# Stock location: "Nobile"

require 'csv'
require 'open3'

class SyncNobileStockJob < SyncStockBaseJob

  CSV_URL = 'https://docs.google.com/spreadsheets/d/e/2PACX-1vSlLyJFMeWNLWcPmQgtjMw8FyXhaexNklYCcEs-3RNmHE824VKY9_G9uIacqi4o41LJkJjFbcfM7p22/pub?gid=337363164&single=true&output=csv'
  STOCK_LOCATION_NAME = 'Nobile'

  def perform
    Rails.logger.info '[NobileStock] Starting Nobile stock sync...'

    # Step 1: Download CSV
    csv_data, status = Open3.capture2(
      'curl', '-s', '--connect-timeout', '30', '--max-time', '60',
      '-L', # follow redirects (Google Sheets uses them)
      CSV_URL
    )

    unless status.success? && csv_data.present?
      raise '[NobileStock] CSV download failed!'
    end

    Rails.logger.info "[NobileStock] Downloaded #{csv_data.lines.count} lines"

    # Step 2: Parse CSV — SKU (col 8) → quantity (col 18 "On hand (new)")
    stock_map = {}
    header_skipped = false

    csv_data.each_line do |line|
      line = line.strip
      next if line.empty?

      unless header_skipped
        header_skipped = true
        next # skip header row
      end

      begin
        row = CSV.parse_line(line)
        next unless row && row.length >= 19

        sku = row[8].to_s.strip
        qty = row[18].to_s.strip.to_i

        next if sku.blank?

        stock_map[sku] = qty
      rescue CSV::MalformedCSVError
        next
      end
    end

    Rails.logger.info "[NobileStock] Parsed #{stock_map.size} SKU entries (#{stock_map.count { |_, q| q > 0 }} with stock)"

    # Step 3: Find stock location
    stock_location = Spree::StockLocation.find_by(name: STOCK_LOCATION_NAME)
    unless stock_location
      raise "[NobileStock] Stock location '#{STOCK_LOCATION_NAME}' not found!"
    end

    # Step 4: Match SKUs to Spree variants — prefer non-master
    matched = 0
    updated = 0
    skipped = 0

    variants_with_skus = Spree::Variant.where(sku: stock_map.keys).includes(:stock_items)
    variant_map = {}
    variants_with_skus.each do |v|
      existing = variant_map[v.sku]
      variant_map[v.sku] = v if existing.nil? || existing.is_master?
    end

    Rails.logger.info "[NobileStock] Matched #{variant_map.size} of #{stock_map.size} SKUs to variants"

    stock_map.each do |sku, new_qty|
      variant = variant_map[sku]
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

    report_sync_stats(matched: matched, updated: updated, skipped: skipped,
                      unmatched: stock_map.size - matched, total_in_feed: stock_map.size)
    Rails.logger.info "[NobileStock] Sync complete — Matched: #{matched}, Updated: #{updated}, Unchanged: #{skipped}, Unmatched: #{stock_map.size - matched}"
  end
end
