# frozen_string_literal: true
# =============================================================================
# JP Wingboard Product Import — from Google Sheets
# Run: RAILS_ENV=production bundle exec rails runner lib/tasks/import_jp_wingboard.rb
#
# Logic:
#   • Groups rows into products by (article number short + color)
#   • Skips any row whose EAN/UPC barcode already exists in Spree::Variant
#   • Creates product + size variants + attaches images
# =============================================================================

require 'csv'
require 'open-uri'
require 'set'

SHEET_URL = 'https://docs.google.com/spreadsheets/d/1_jOL9D8uk--RNxLJW8hSuNU7oVtl8Ax823API7Qf39U/export?format=csv'
STORE_ID  = 2

# Map product name → Spree taxon permalink
CATEGORY_MAP = {
  'WingAir SE'              => 'categories/wingfoil/wings/wing',
  'S-Winger'                => 'categories/wingfoil/wings/wing',
  'M-Winger'                => 'categories/wingfoil/wings/wing',
  'F-Winger'                => 'categories/wingfoil/wings/wing',
  'X-Winger'                => 'categories/wingfoil/wings/wing',
  'XR'                      => 'categories/wingfoil/wing-boards/wingboard',
  'Downwind'                => 'categories/wingfoil/wing-boards/wingboard',
  'E-ZEE'                   => 'categories/wingfoil/wing-boards/wingboard',
  'RS'                      => 'categories/wingfoil/wing-boards/wingboard',
  'WingAir Foil Screw M8x20'=> 'categories/wingfoil/wing-accessories'
}.freeze

BRAND_PERMALINK = 'brands/jp-australia'

def log(msg) = puts("[JP Wing] #{msg}")

# ---------------------------------------------------------------------------
log 'Downloading CSV from Google Sheets...'
raw  = URI.open(SHEET_URL, read_timeout: 30).read.force_encoding('UTF-8')
rows = CSV.parse(raw, headers: true)
log "Downloaded #{rows.size} variant rows"

# ---------------------------------------------------------------------------
existing_barcodes = Set.new(
  Spree::Variant.where.not(barcode: [nil, '']).pluck(:barcode).map(&:to_s)
)
log "#{existing_barcodes.size} barcodes already in DB"

store        = Spree::Store.find(STORE_ID)
shipping_cat = Spree::ShippingCategory.find(1)
stock_location = Spree::StockLocation.find_by!(name: 'Pryde')
brand_taxon    = Spree::Taxon.find_by!(permalink: BRAND_PERMALINK)

size_option = Spree::OptionType.find_or_create_by!(name: 'size') do |o|
  o.presentation = 'Size'
end

# ---------------------------------------------------------------------------
product_groups = rows.group_by { |r| "#{r['article number short']}_#{r['color']}" }
log "#{product_groups.size} product groups to process"

created_products = 0
updated_products = 0
created_variants = 0
skipped_variants = 0
errors           = []

# ---------------------------------------------------------------------------
product_groups.each do |_key, variant_rows|
  first        = variant_rows.first
  product_name = first['product name'].to_s.strip
  color        = first['color'].to_s.strip
  season       = first['product season'].to_s.strip
  art_short    = first['article number short'].to_s.strip
  retail_price = first['retail EURO'].to_f

  # Build description from EN HTML + EN key features
  desc_html = first['description_EN_HTML'].to_s.strip
  key_feats = [
    first['Key Features_EN_1'],
    first['Key Features_EN_2'],
    first['Key Features_EN_3'],
    first['Key Features_EN_4'],
    first['Key Features_EN_5']
  ].map(&:to_s).map(&:strip).reject(&:empty?)
  if key_feats.any?
    bullets = key_feats.map { |f| "<li>#{f}</li>" }.join
    desc_html += "<ul>#{bullets}</ul>"
  end
  desc_html = desc_html.presence || first['descrition_EN'].to_s.strip

  full_name = "JP #{product_name} #{color} #{season}".strip
  slug      = "jp-#{product_name}-#{color}-#{art_short}"
                .downcase.gsub(/[^a-z0-9]+/, '-').gsub(/-+/, '-').chomp('-')

  # Skip if ALL barcodes already exist
  all_eans = variant_rows.map { |r| r['EAN/UPC'].to_s.strip }.reject(&:empty?)
  if all_eans.any? && all_eans.all? { |ean| existing_barcodes.include?(ean) }
    log "  SKIP (all #{all_eans.size} barcodes exist): #{full_name}"
    skipped_variants += all_eans.size
    next
  end

  # ------------------------------------------------------------------
  # Find or create product
  # ------------------------------------------------------------------
  product = Spree::Product.find_by(slug: slug) ||
            Spree::Product.find_by('name ILIKE ?', full_name)

  if product.nil?
    product = Spree::Product.new(
      name:              full_name,
      description:       desc_html,
      price:             retail_price.positive? ? retail_price : 1.0,
      currency:          'EUR',
      slug:              slug,
      shipping_category: shipping_cat,
      available_on:      Time.current,
      status:            'active'
    )
    product.stores << store
    product.save!

    # Assign taxons
    cat_permalink = CATEGORY_MAP.find { |k, _| product_name.include?(k) }&.last ||
                    'categories/wingfoil/wing-boards/wingboard'
    cat_taxon = Spree::Taxon.find_by(permalink: cat_permalink)
    product.taxons = [brand_taxon, cat_taxon].compact
    product.save!

    log "  CREATED: #{full_name} (id=#{product.id})"
    created_products += 1
  else
    log "  EXISTS: #{full_name} (id=#{product.id}) — adding missing variants"
    updated_products += 1
  end

  product.option_types << size_option unless product.option_types.include?(size_option)

  # ------------------------------------------------------------------
  # Create missing variants
  # ------------------------------------------------------------------
  variant_rows.each do |row|
    ean       = row['EAN/UPC'].to_s.strip
    size      = row['size'].to_s.strip
    var_price = row['retail EURO'].to_f

    if existing_barcodes.include?(ean)
      log "    SKIP variant size=#{size} EAN=#{ean}"
      skipped_variants += 1
      next
    end

    begin
      # Normalize size: Spree replaces commas/dots with dashes in option value names
      normalized_size = size.gsub(',', '-').gsub('.', '-')

      size_ov = Spree::OptionValue.find_by(option_type: size_option, name: normalized_size) ||
                Spree::OptionValue.create!(
                  option_type:  size_option,
                  name:         normalized_size,
                  presentation: size   # keep original for display (e.g. "5,4")
                )

      variant = product.variants.create!(
        sku:           "JP-#{art_short}-#{color.gsub(/\s+/, '')}-#{size.gsub(',', '.')}",
        barcode:       ean,
        currency:      'EUR',
        option_values: [size_ov]
      )

      price_rec = variant.prices.find_or_initialize_by(currency: 'EUR')
      price_rec.amount = var_price.positive? ? var_price : retail_price
      price_rec.save!

      si = variant.stock_items.find_or_create_by!(stock_location: stock_location)
      si.update!(count_on_hand: 0, backorderable: false)

      existing_barcodes.add(ean)
      created_variants += 1
      log "    + variant size=#{size} EAN=#{ean}"
    rescue => e
      msg = "ERROR variant EAN=#{ean} size=#{size}: #{e.message[0..120]}"
      log "    #{msg}"
      errors << msg
    end
  end

  # ------------------------------------------------------------------
  # Attach images (up to 5)
  # ------------------------------------------------------------------
  next if product.master.images.count >= 5

  attached = 0
  (1..22).each do |i|
    break if attached >= 5
    url = first["Image direct link #{i}"].to_s.strip
    next if url.empty?

    begin
      io       = URI.open(url, read_timeout: 20, open_timeout: 10)
      filename = url.split('/').last.split('?').first
      next if filename.blank?

      img = Spree::Image.new(viewable: product.master)
      img.attachment.attach(io: io, filename: filename, content_type: 'image/png')
      img.save!
      attached += 1
      log "    IMG #{i}: #{filename}"
    rescue => e
      log "    IMG #{i} FAILED: #{e.message[0..80]}"
    end
  end
end

# ---------------------------------------------------------------------------
log ''
log '=== IMPORT COMPLETE ==='
log "Products created:  #{created_products}"
log "Products updated:  #{updated_products}"
log "Variants created:  #{created_variants}"
log "Variants skipped:  #{skipped_variants}"
log "Errors:            #{errors.size}"
errors.each { |e| log "  #{e}" }
