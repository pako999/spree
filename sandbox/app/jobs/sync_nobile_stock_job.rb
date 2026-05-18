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

    # Step 4: Match SKUs to Spree variants — two-pass matching:
    #   Pass 1: Exact SKU match
    #   Pass 2: Fuzzy match — normalize year (K24/K23 → K25) and strip
    #           Nobile dimension suffix (e.g. -136X41) from Spree SKUs
    matched = 0
    updated = 0
    skipped = 0

    # Pass 1: Exact match
    exact_variant_map = {}
    Spree::Variant.where(sku: stock_map.keys).includes(:stock_items).each do |v|
      existing = exact_variant_map[v.sku]
      exact_variant_map[v.sku] = v if existing.nil? || existing.is_master?
    end

    unmatched_skus = stock_map.keys - exact_variant_map.keys

    # Pass 2: Fuzzy prefix match for unmatched SKUs
    # Strategy: normalize the CSV SKU year (K24→K25, K23→K25, K22→K25)
    # and find Spree variants whose SKU starts with that normalized prefix.
    # Multiple Spree variants may share one CSV SKU (different board dimensions —
    # same product, different size boards). We apply the CSV stock to ALL of them.
    fuzzy_variant_map = Hash.new { |h, k| h[k] = [] } # csv_sku → [variants]

    if unmatched_skus.any?
      # Build a normalized-prefix index of all Nobile-related variants
      all_nobile_variants = Spree::Variant
        .joins(:product)
        .where("spree_variants.sku ILIKE ANY (ARRAY[?])", ['K25-NOB-%', 'K25-NOB-%', 'UB%NOB%', 'AL%-%', 'AF%NOB%', 'AK%NOB%'])
        .includes(:stock_items, :product)

      # Index: normalized_base_sku → [variants]
      nobile_index = Hash.new { |h, k| h[k] = [] }
      all_nobile_variants.each do |v|
        normalized = normalize_nobile_sku(v.sku)
        nobile_index[normalized] << v unless v.is_master?
      end

      unmatched_skus.each do |csv_sku|
        normalized_csv = normalize_nobile_sku(csv_sku)
        matches = nobile_index[normalized_csv]
        fuzzy_variant_map[csv_sku] = matches if matches.any?
      end

      Rails.logger.info "[NobileStock] Fuzzy matched #{fuzzy_variant_map.size} of #{unmatched_skus.size} unmatched SKUs"
    end

    # Apply stock updates
    stock_map.each do |sku, new_qty|
      # Exact match — single variant
      if (variant = exact_variant_map[sku])
        matched += 1
        apply_stock(variant, stock_location, new_qty, updated: ->(){ updated += 1 }, skipped: ->(){ skipped += 1 })
        next
      end

      # Fuzzy match — may be multiple variants (different board dimensions)
      variants = fuzzy_variant_map[sku]
      next unless variants&.any?

      # Distribute stock evenly across all matched size variants
      per_variant_qty = (new_qty.to_f / variants.size).ceil
      variants.each do |variant|
        matched += 1
        apply_stock(variant, stock_location, per_variant_qty, updated: ->(){ updated += 1 }, skipped: ->(){ skipped += 1 })
      end
    end

    report_sync_stats(matched: matched, updated: updated, skipped: skipped,
                      unmatched: stock_map.size - exact_variant_map.size - fuzzy_variant_map.size,
                      total_in_feed: stock_map.size)
    Rails.logger.info "[NobileStock] Sync complete — Matched: #{matched}, Updated: #{updated}, Unchanged: #{skipped}, Unmatched: #{stock_map.size - exact_variant_map.size - fuzzy_variant_map.size}"
  end

  private

  # Normalize a Nobile SKU for fuzzy matching:
  #   1. Upcase
  #   2. Normalize year prefix: K22/K23/K24 → K25
  #   3. Strip board dimension suffix (e.g. -136X41, -139X42, -2 duplicate suffix)
  def normalize_nobile_sku(sku)
    s = sku.to_s.upcase.strip
    # Year normalization: K22-, K23-, K24- → K25-
    s = s.sub(/\AK2[234]-/, 'K25-')
    # Strip trailing dimension (e.g. -136X41, -139X42, -150X45)
    s = s.sub(/-\d{3}X\d{2,3}(-\d+)?\z/, '')
    # Strip trailing -2, -3 duplicate markers
    s = s.sub(/-\d+\z/, '') if s.match?(/-\d+\z/) && !s.match?(/-1ST\z/i)
    s
  end

  # Apply stock update to a single variant at the given location
  def apply_stock(variant, stock_location, new_qty, updated:, skipped:)
    stock_item = variant.stock_items.find { |si| si.stock_location_id == stock_location.id }
    if stock_item
      if stock_item.count_on_hand != new_qty
        stock_item.set_count_on_hand(new_qty)
        updated.call
      else
        skipped.call
      end
    else
      stock_location.stock_items.create!(variant: variant, count_on_hand: new_qty, backorderable: false)
      updated.call
    end
  end
end
