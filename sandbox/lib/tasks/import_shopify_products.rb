# frozen_string_literal: true
# =============================================================================
# Shopify-format CSV Product Import
# Sheet: https://docs.google.com/spreadsheets/d/1nsCbI2Fbj_Tk6zyyEwhZTixAE0Qzn7X_oC1NToMx4Gc
#
# Logic:
#   • Groups rows by Handle (Shopify product grouping)
#   • If ALL variant barcodes already exist in DB → skip product
#   • Otherwise → create product + variants (skip individual existing barcodes)
#   • Attaches product image from Image Src
# =============================================================================
require 'csv'
require 'open-uri'
require 'set'

SHEET_ID  = '1nsCbI2Fbj_Tk6zyyEwhZTixAE0Qzn7X_oC1NToMx4Gc'
SHEET_URL = "https://docs.google.com/spreadsheets/d/#{SHEET_ID}/export?format=csv"
STORE_ID  = 2

def log(msg) = puts("[Import] #{msg}")

# ---------------------------------------------------------------------------
log 'Downloading CSV from Google Sheets...'
raw  = URI.open(SHEET_URL, read_timeout: 30).read.force_encoding('UTF-8')
rows = CSV.parse(raw, headers: true)
log "Downloaded #{rows.size} rows"

# ---------------------------------------------------------------------------
# Preload existing barcodes
existing_barcodes = Set.new(
  Spree::Variant.where.not(barcode: [nil, '']).pluck(:barcode).map(&:to_s).map(&:strip)
)
log "#{existing_barcodes.size} barcodes already in DB"

store         = Spree::Store.find(STORE_ID)
shipping_cat  = Spree::ShippingCategory.find(1)
stock_loc     = Spree::StockLocation.find_by!(name: 'Boards And More')

# ---------------------------------------------------------------------------
# Option types — find or create Color + Size
color_option = Spree::OptionType.find_or_create_by!(name: 'color') { |o| o.presentation = 'Color' }
size_option  = Spree::OptionType.find_or_create_by!(name: 'size')  { |o| o.presentation = 'Size' }

# Spree normalizes option value names: lowercase, colons/spaces → hyphens
# e.g. "C56:grey" → "c56-grey", "C99:random" → "c99-random"
def normalize_ov_name(name)
  name.to_s.strip.downcase.gsub(/[:\s]+/, '-').gsub(/-+/, '-').chomp('-')
end

def find_or_create_option_value(option_type, name)
  return nil if name.blank?
  normalized = normalize_ov_name(name)
  # 1. Exact match
  existing = Spree::OptionValue.find_by(option_type: option_type, name: normalized)
  return existing if existing
  # 2. Try to create
  ov = Spree::OptionValue.new(option_type: option_type, name: normalized,
                               presentation: name.to_s.strip)
  return ov if ov.save
  # 3. Creation failed (uniqueness) — find via LOWER() to catch encoding/case edge cases
  Spree::OptionValue
    .where(option_type_id: option_type.id)
    .where("LOWER(name) = LOWER(?)", normalized)
    .first
end

# ---------------------------------------------------------------------------
# Helper: best-effort taxon lookup by Vendor (brand) and Type (category)
def find_taxons(vendor, type)
  taxons = []

  # Brand taxon
  brand = Spree::Taxon.where("name ILIKE ?", "%#{vendor.to_s.split('&').first.strip}%")
                      .where("depth >= 1").first
  taxons << brand if brand

  # Category taxon by type keyword
  if type.present?
    cat = Spree::Taxon.where("name ILIKE ?", "%#{type.strip}%")
                      .where("permalink LIKE 'categories/%'").first
    taxons << cat if cat
  end

  taxons.compact.uniq
end

# ---------------------------------------------------------------------------
# Group rows by Handle
product_groups = rows.group_by { |r| r['Handle'].to_s.strip }
log "#{product_groups.size} product groups to process"

created_products = 0
skipped_products = 0
created_variants = 0
skipped_variants = 0
errors           = []

# ---------------------------------------------------------------------------
product_groups.each do |handle, variant_rows|
  next if handle.blank?

  first = variant_rows.first
  title = first['Title'].to_s.strip
  next if title.blank?

  # Collect all barcodes for this product
  all_barcodes = variant_rows
    .map { |r| r['Variant Barcode'].to_s.strip }
    .reject(&:empty?)

  # Skip entire product if ALL barcodes already exist
  if all_barcodes.any? && all_barcodes.all? { |b| existing_barcodes.include?(b) }
    log "  SKIP (all #{all_barcodes.size} barcodes exist): #{title}"
    skipped_products += 1
    skipped_variants += all_barcodes.size
    next
  end

  vendor     = first['Vendor'].to_s.strip
  type       = first['Type'].to_s.strip
  desc_html  = first['Body (HTML)'].to_s.strip
  price      = first['Variant Price'].to_s.strip.to_f
  price      = 1.0 if price <= 0
  status     = first['Status'].to_s.strip == 'active' ? 'active' : 'draft'
  image_url  = first['Image Src'].to_s.strip

  slug = handle.downcase.gsub(/[^a-z0-9]+/, '-').gsub(/-+/, '-').chomp('-')

  # ------------------------------------------------------------------
  # Find or create product
  # ------------------------------------------------------------------
  product = Spree::Product.find_by(slug: slug) ||
            Spree::Product.find_by('name ILIKE ?', title)

  if product.nil?
    begin
      product = Spree::Product.new(
        name:              title,
        description:       desc_html.presence || title,
        price:             price,
        currency:          'EUR',
        slug:              slug,
        shipping_category: shipping_cat,
        available_on:      Time.current,
        status:            status
      )
      product.stores << store
      product.save!

      # Assign taxons
      taxons = find_taxons(vendor, type)
      product.taxons = taxons if taxons.any?
      product.save!

      # Attach product image
      if image_url.present?
        begin
          io       = URI.open(image_url, read_timeout: 20, open_timeout: 10,
                              'User-Agent' => 'Mozilla/5.0')
          filename = image_url.split('/').last.split('?').first
          filename = "#{slug}.jpg" if filename.blank?
          img = Spree::Image.new(viewable: product.master)
          img.attachment.attach(io: io, filename: filename,
                                content_type: 'image/jpeg')
          img.save!
          log "    IMG: #{filename}"
        rescue => e
          log "    IMG FAILED: #{e.message[0..80]}"
        end
      end

      log "  CREATED: #{title} (id=#{product.id}, status=#{status})"
      created_products += 1
    rescue => e
      msg = "ERROR creating product #{title}: #{e.message[0..120]}"
      log "  #{msg}"
      errors << msg
      next
    end
  else
    log "  EXISTS: #{title} (id=#{product.id}) — checking variants"
  end

  # Determine which option types this product uses
  opt1_name = first['Option1 Name'].to_s.strip
  opt2_name = first['Option2 Name'].to_s.strip
  has_color = opt1_name.downcase.include?('color') || opt1_name.downcase.include?('colour')
  has_size  = opt2_name.downcase.include?('size') || opt1_name.downcase.include?('size')

  if has_color && !product.option_types.include?(color_option)
    product.option_types << color_option
  end
  if has_size && !product.option_types.include?(size_option)
    product.option_types << size_option
  end

  # ------------------------------------------------------------------
  # Create missing variants
  # ------------------------------------------------------------------

  # For single-variant products (one row only) → set barcode on master variant
  if variant_rows.size == 1
    row     = variant_rows.first
    barcode = row['Variant Barcode'].to_s.strip
    next if barcode.blank?

    if existing_barcodes.include?(barcode)
      log "    SKIP master variant barcode=#{barcode}"
      skipped_variants += 1
      next
    end

    begin
      master = product.master
      master.update!(
        barcode:  barcode,
        sku:      row['Variant SKU'].to_s.strip.presence || "#{slug}-#{barcode}"
      )
      p_rec = master.prices.find_or_initialize_by(currency: 'EUR')
      p_rec.amount = row['Variant Price'].to_s.to_f.then { |v| v > 0 ? v : price }
      p_rec.save!
      si = master.stock_items.find_or_create_by!(stock_location: stock_loc)
      si.update!(count_on_hand: 0, backorderable: false)
      existing_barcodes.add(barcode)
      created_variants += 1
      log "    + master barcode=#{barcode}"
    rescue => e
      msg = "ERROR updating master barcode=#{barcode}: #{e.message[0..120]}"
      log "  #{msg}"; errors << msg
    end
    next
  end

  # Multi-variant products → create proper variants with option values
  variant_rows.each do |row|
    barcode = row['Variant Barcode'].to_s.strip
    next if barcode.blank?

    if existing_barcodes.include?(barcode)
      log "    SKIP variant barcode=#{barcode}"
      skipped_variants += 1
      next
    end

    begin
      opt1_val  = row['Option1 Value'].to_s.strip
      opt2_val  = row['Option2 Value'].to_s.strip
      sku       = row['Variant SKU'].to_s.strip.presence || "#{slug}-#{barcode}"
      var_price = row['Variant Price'].to_s.to_f
      var_price = price if var_price <= 0
      compare_at = row['Variant Compare At Price'].to_s.to_f

      option_values = []

      if opt1_val.present?
        ov1 = find_or_create_option_value(color_option, opt1_val)
        option_values << ov1 if ov1
        product.option_types << color_option unless product.option_types.include?(color_option)
      end

      if opt2_val.present?
        ov2 = find_or_create_option_value(size_option, opt2_val)
        option_values << ov2 if ov2
        product.option_types << size_option unless product.option_types.include?(size_option)
      end

      variant = product.variants.create!(
        sku:           sku,
        barcode:       barcode,
        currency:      'EUR',
        option_values: option_values.compact
      )

      price_rec = variant.prices.find_or_initialize_by(currency: 'EUR')
      price_rec.amount = var_price
      price_rec.save!

      si = variant.stock_items.find_or_create_by!(stock_location: stock_loc)
      si.update!(count_on_hand: 0, backorderable: false)

      var_img_url = row['Variant Image'].to_s.strip
      if var_img_url.present? && var_img_url != image_url
        begin
          io = URI.open(var_img_url, read_timeout: 20, open_timeout: 10, 'User-Agent' => 'Mozilla/5.0')
          vf = var_img_url.split('/').last.split('?').first.presence || "#{barcode}.jpg"
          vimg = Spree::Image.new(viewable: variant)
          vimg.attachment.attach(io: io, filename: vf, content_type: 'image/jpeg')
          vimg.save!
        rescue => e
          log "    Variant IMG FAILED: #{e.message[0..60]}"
        end
      end

      existing_barcodes.add(barcode)
      created_variants += 1
      log "    + variant sku=#{sku} barcode=#{barcode}"
    rescue => e
      msg = "ERROR creating variant barcode=#{barcode}: #{e.message[0..120]}"
      log "  #{msg}"; errors << msg
    end
  end
end

# ---------------------------------------------------------------------------
log ''
log '=== IMPORT COMPLETE ==='
log "Products created:  #{created_products}"
log "Products skipped:  #{skipped_products}"
log "Variants created:  #{created_variants}"
log "Variants skipped:  #{skipped_variants}"
log "Errors:            #{errors.size}"
errors.each { |e| log "  ERROR: #{e}" }
