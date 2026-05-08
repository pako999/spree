# frozen_string_literal: true
# =============================================================================
# Cabrinha Product Import — from Google Sheets
# Run: RAILS_ENV=production bundle exec rails runner lib/tasks/import_cabrinha.rb
#
# Groups: Cab. Kites, Cab. Kiteboards, Cab. Wing, Cab. Wingboard, Cab. Ersatzt. Wingb.
# Skips any row whose EAN/UPC barcode already exists in Spree::Variant
# =============================================================================

require 'csv'
require 'open-uri'
require 'set'

SHEET_URL = 'https://docs.google.com/spreadsheets/d/1nk-NW2QXQo6uTGr00AJ2q62svZS_q3muS7_SKQVZc_s/export?format=csv'
STORE_ID  = 2

# Map product group → { category, brand }
GROUP_MAP = {
  'Cab. Kites'          => { cat: 'categories/kitesurfing/kites/kite',
                              brand: 'brands/cabrinha/kites' },
  'Cab. Kiteboards'     => { cat: 'categories/kitesurfing/kiteboards/kiteboard',
                              brand: 'brands/cabrinha/boards' },
  'Cab. Wing'           => { cat: 'categories/wingfoil/wings/wing',
                              brand: 'brands/cabrinha/wings' },
  'Cab. Wingboard'      => { cat: 'categories/wingfoil/wing-boards/wingboard',
                              brand: 'brands/cabrinha' },
  'Cab. Ersatzt. Wingb.'=> { cat: 'categories/wingfoil/wing-accessories/wing-spare-parts',
                              brand: 'brands/cabrinha/accessories' }
}.freeze

# Override category for specific product name patterns (foil kits inside Cab. Wingboard group)
PRODUCT_NAME_CAT_OVERRIDE = {
  'Rebound Wing Kit'    => 'categories/wingfoil/wing-foils/wing-foil-wing-sets',
  'Rebound Front Wing'  => 'categories/wingfoil/wing-foils/foil',
  'Whippit Wing Kit'    => 'categories/wingfoil/wing-foils/wing-foil-wing-sets',
  'Whippit Front Wing'  => 'categories/wingfoil/wing-foils/foil'
}.freeze

DEFAULT_MAP = { cat: 'categories/kitesurfing/kiteboards/kiteboard', brand: 'brands/cabrinha' }

def log(msg) = puts("[Cabrinha] #{msg}")

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

store          = Spree::Store.find(STORE_ID)
shipping_cat   = Spree::ShippingCategory.find(1)
stock_location = Spree::StockLocation.find_by!(name: 'Pryde')  # Cabrinha via NeilPryde

size_option = Spree::OptionType.find_or_create_by!(name: 'size') do |o|
  o.presentation = 'Size'
end

# Preload taxon lookups
taxon_cache = {}
taxon_lookup = ->(permalink) {
  taxon_cache[permalink] ||= Spree::Taxon.find_by(permalink: permalink)
}

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
  prod_group   = first['product group'].to_s.strip
  retail_price = first['retail EURO'].to_f

  # Build description
  desc_html  = first['description_EN_HTML'].to_s.strip
  plain_desc = first['descrition_EN'].to_s.strip
  key_feats  = (1..5).map { |i| first["Key Features_EN_#{i}"].to_s.strip }.reject(&:empty?)
  if key_feats.any?
    bullets = key_feats.map { |f| "<li>#{f}</li>" }.join
    desc_html += "<ul>#{bullets}</ul>"
  end
  desc_html = desc_html.presence || plain_desc

  full_name = "Cabrinha #{product_name} #{season}".gsub(/\s+/, ' ').strip
  slug      = "cabrinha-#{product_name}-#{color}-#{art_short}"
                .downcase.gsub(/[^a-z0-9]+/, '-').gsub(/-+/, '-').chomp('-')

  # Skip if ALL barcodes already exist
  all_eans = variant_rows.map { |r| r['EAN/UPC'].to_s.strip }.reject(&:empty?)
  if all_eans.any? && all_eans.all? { |ean| existing_barcodes.include?(ean) }
    log "  SKIP (all #{all_eans.size} barcodes exist): #{full_name}"
    skipped_variants += all_eans.size
    next
  end

  # ------------------------------------------------------------------
  # Resolve taxons
  # ------------------------------------------------------------------
  mapping     = GROUP_MAP[prod_group] || DEFAULT_MAP
  cat_perm    = PRODUCT_NAME_CAT_OVERRIDE.find { |k, _| product_name.include?(k) }&.last ||
                mapping[:cat]
  brand_perm  = mapping[:brand]

  cat_taxon   = taxon_lookup.call(cat_perm)
  brand_taxon = taxon_lookup.call(brand_perm)

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
      normalized_size = size.gsub(',', '-').gsub('.', '-')

      size_ov = Spree::OptionValue.find_by(option_type: size_option, name: normalized_size) ||
                Spree::OptionValue.create!(
                  option_type:  size_option,
                  name:         normalized_size,
                  presentation: size
                )

      variant = product.variants.create!(
        sku:           "CAB-#{art_short}-#{color.gsub(/[^a-zA-Z0-9]/, '-')}-#{normalized_size}",
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
      msg = "ERROR EAN=#{ean} size=#{size}: #{e.message[0..120]}"
      log "    #{msg}"
      errors << msg
    end
  end

  # ------------------------------------------------------------------
  # Attach images (up to 5)
  # ------------------------------------------------------------------
  next if product.master.images.count >= 5

  attached = 0
  (1..6).each do |i|
    break if attached >= 5
    url = first["Image direct link #{i}"].to_s.strip
    next if url.empty?

    begin
      io       = URI.open(url, read_timeout: 20, open_timeout: 10)
      filename = url.split('/').last.split('?').first
      next if filename.blank?

      ext = File.extname(filename).downcase
      content_type = ext == '.jpg' || ext == '.jpeg' ? 'image/jpeg' : 'image/png'

      img = Spree::Image.new(viewable: product.master)
      img.attachment.attach(io: io, filename: filename, content_type: content_type)
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
