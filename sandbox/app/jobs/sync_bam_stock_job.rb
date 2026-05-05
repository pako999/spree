# Boards & More B2B Stock Sync Job
# Downloads stock CSV from FTP and updates Spree variant stock items.
# Scheduled via Solid Queue recurring jobs (config/recurring.yml).
#
# FTP: ftp://hookipa.boards-and-more.com/availableQuantities_INT.csv
# Format: EAN;quantity (semicolon-separated, no header)

require "open3"

class SyncBamStockJob < SyncStockBaseJob

  FTP_HOST     = "hookipa.boards-and-more.com"
  FTP_USER     = "as_int"
  FTP_PASSWORD = "Tesla70724"
  FTP_FILE     = "availableQuantities_INT.csv"

  def perform
    Rails.logger.info "[BamStock] Starting Boards & More stock sync..."

    # Step 1: Download stock CSV from FTP
    # --connect-timeout: max time to establish connection
    # --max-time: hard cap on total transfer time (prevents infinite hang)
    csv_data, status = Open3.capture2(
      "curl", "-s", "--connect-timeout", "30", "--max-time", "120",
      "ftp://#{FTP_USER}:#{FTP_PASSWORD}@#{FTP_HOST}/#{FTP_FILE}"
    )

    unless status.success? && csv_data.present?
      raise "[BamStock] FTP download failed (exit #{status.exitstatus})!"
    end

    Rails.logger.info "[BamStock] Downloaded #{csv_data.lines.count} lines from FTP"

    # Step 2: Parse CSV into EAN → quantity hash
    stock_map = {}
    csv_data.each_line do |line|
      line = line.strip
      next if line.empty?
      parts = line.split(";")
      next if parts.length < 2
      ean = parts[0].strip
      qty = parts[1].strip.to_i
      stock_map[ean] = qty
    end

    Rails.logger.info "[BamStock] Parsed #{stock_map.size} EAN entries (#{stock_map.count { |_, q| q > 0 }} with stock)"

    # Step 3: Match EANs to Spree variants and update stock
    stock_location = Spree::StockLocation.find_by(name: "Boards And More")
    unless stock_location
      raise "[BamStock] 'Boards And More' stock location not found!"
    end

    matched = 0
    updated = 0
    skipped = 0

    # Get all variants with matching barcodes in one query.
    # IMPORTANT: group by barcode and always prefer non-master variants.
    # When a product has real variants (sizes/colors), both the master and the
    # variant share the same EAN — we must update the sellable variant, not the master.
    variants_with_barcodes = Spree::Variant
                               .where(barcode: stock_map.keys)
                               .includes(:stock_items)

    # Build EAN → best_variant map: prefer non-master over master
    variant_map = {}
    variants_with_barcodes.each do |v|
      existing = variant_map[v.barcode]
      # Prefer non-master; only fall back to master if nothing better found
      if existing.nil? || existing.is_master?
        variant_map[v.barcode] = v
      end
    end

    Rails.logger.info "[BamStock] Matched #{variant_map.size} of #{stock_map.size} EANs to variants"

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

    report_sync_stats(matched: matched, updated: updated, skipped: skipped,
                      unmatched: stock_map.size - matched, total_in_feed: stock_map.size)
    Rails.logger.info "[BamStock] Sync complete — Matched: #{matched}, Updated: #{updated}, Unchanged: #{skipped}, Unmatched: #{stock_map.size - matched}"
  end
end
