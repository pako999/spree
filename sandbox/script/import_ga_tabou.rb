# frozen_string_literal: true
# GA / Tabou 2026 product import from Google Sheets CSV (custom format)
# Groups rows by preceding V-row (product header). Skips if any barcode already exists.
# Run: bin/kamal app exec --reuse "bin/rails runner /rails/script/import_ga_tabou.rb"

require 'csv'
require 'net/http'
require 'uri'
require 'tempfile'
require 'open-uri'

CURRENCY = 'EUR'
CSV_URL  = 'https://docs.google.com/spreadsheets/d/1Sr4GYYICLOMUS3g_JFm4v3ildnSPWfHw9Ea5AeeDm3I/export?format=csv'

BRAND_TAXON_MAP = {
  'Tabou'    => 'brands/tabou',
  'GA-Sails' => 'brands/gaastra',
  'GA-Kites' => 'brands/gaastra',
  'GA-Wing'  => 'brands/gaastra',
  'GA Masts' => 'brands/gaastra',
  'GA Booms' => 'brands/gaastra',
  'GA'       => 'brands/gaastra',
}.freeze

CATEGORY_MAP = {
  'Windsurfboards'       => 'categories/windsurf/windsurf-boards',
  'Windsurfsails'        => 'categories/windsurf/windsurf-sails',
  'Kites'                => 'categories/kitesurfing/kites',
  'Kiteboards'           => 'categories/kitesurfing/kiteboards',
  'Wings'                => 'categories/wingfoil/wings',
  'Harness'              => 'categories/windsurf/windsurf-harnesses',
  'Foil'                 => 'categories/wingfoil/wing-foils',
  'Wingfoil Boards'      => 'categories/wingfoil/wing-boards',
  'Windsurfmasts'        => 'categories/windsurf/windsurf-gear',
  'WindsurfingBooms'     => 'categories/windsurf/windsurf-gear',
  'Boardaccessories'     => 'categories/windsurf/windsurf-accessories',
  'Kiteboardaccessories' => 'categories/kitesurfing/kite-accessories',
  'Mastaccessories'      => 'categories/windsurf/windsurf-accessories',
  'Boomaccessories'      => 'categories/windsurf/windsurf-accessories',
  'Accessories'          => 'categories/windsurf/windsurf-accessories',
  'Riggs'                => 'categories/windsurf/windsurf-gear',
  'Kiteparts'            => 'categories/kitesurfing/kite-accessories',
}.freeze

def parse_price(str)
  return 0.0 if str.blank?
  str.to_s.gsub(',', '').gsub(/\s*EUR\s*/, '').strip.to_f
end

def image_urls_from_row(row)
  (0..6).map { |i| row["ImageURLpng#{i}"].presence }.compact
end

def download_image(url_str)
  uri = URI.parse(url_str)
  tries = 0
  loop do
    tries += 1
    return nil if tries > 5
    res = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == 'https', open_timeout: 10, read_timeout: 20) do |http|
      req = Net::HTTP::Get.new(uri)
      req['User-Agent'] = 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36'
      req['Accept']     = 'image/*,*/*;q=0.8'
      http.request(req)
    end
    case res
    when Net::HTTPSuccess
      return nil if res.body.to_s.empty?
      ext  = File.extname(uri.path).split('?').first.downcase.presence || '.png'
      ext  = '.png' unless ['.jpg', '.jpeg', '.png', '.webp', '.gif'].include?(ext)
      tmpf = Tempfile.new(['img', ext])
      tmpf.binmode
      tmpf.write(res.body)
      tmpf.rewind
      return tmpf
    when Net::HTTPRedirection
      uri = URI.parse(res['location'])
    else
      return nil
    end
  end
rescue => e
  puts " [dl err: #{e.message.truncate(50)}]"
  nil
end

def attach_image(record, url)
  tmpf = download_image(url)
  return false unless tmpf
  fname = File.basename(URI.parse(url).path).split('?').first
  fname = "image.png" if fname.blank?
  ext   = File.extname(fname).downcase
  ctype = case ext
          when '.jpg', '.jpeg' then 'image/jpeg'
          when '.webp'         then 'image/webp'
          when '.gif'          then 'image/gif'
          else 'image/png'
          end
  record.images.create!(attachment: { io: tmpf, filename: fname, content_type: ctype })
  true
rescue => e
  puts " [attach err: #{e.message.truncate(60)}]"
  false
end

def find_or_build_option_value(option_type, raw_val)
  normalized = raw_val.to_s.parameterize
  Spree::OptionValue.find_by(option_type_id: option_type.id, name: normalized) ||
    Spree::OptionValue.create!(option_type: option_type, name: normalized, presentation: raw_val.to_s)
end

puts "Downloading CSV..."
csv_data = URI.open(CSV_URL, 'User-Agent' => 'Mozilla/5.0').read.force_encoding('UTF-8')

# Group rows: each V row starts a new product group; non-V rows appended to current group
products_data = []
current_group = nil

CSV.parse(csv_data, headers: true, encoding: 'UTF-8') do |row|
  h = row.to_h.transform_values { |v| v&.encode('UTF-8', invalid: :replace, undef: :replace)&.strip }
  sku = h['SKU'].to_s.strip
  next if sku.blank?

  if sku.start_with?('V')
    current_group = { v_row: h, variants: [] }
    products_data << current_group
  else
    # Attach to current group if one exists, otherwise create anonymous group
    if current_group.nil?
      current_group = { v_row: nil, variants: [] }
      products_data << current_group
    end
    current_group[:variants] << h
  end
end

# Drop groups with no variants
products_data.reject! { |g| g[:variants].empty? }
puts "Product groups found: #{products_data.size}"

# Preload taxons
brand_taxons    = BRAND_TAXON_MAP.transform_values { |p| Spree::Taxon.find_by(permalink: p) }
category_taxons = CATEGORY_MAP.transform_values    { |p| Spree::Taxon.find_by(permalink: p) }

shipping_category = Spree::ShippingCategory.find(1)
store             = Spree::Store.find(2)

# Cache option types
option_type_cache = {}
def find_or_create_ot(cache, raw_name)
  key = raw_name.to_s.downcase.parameterize
  cache[key] ||= Spree::OptionType.find_or_create_by!(name: key) { |o| o.presentation = raw_name.to_s.titleize }
end

imported = 0
skipped  = 0
errors   = 0
total    = products_data.size
start_at = Time.current

products_data.each_with_index do |group, idx|
  v_row    = group[:v_row]
  variants = group[:variants]

  # Collect all barcodes
  barcodes = variants.map { |r| r['BARCODE'] }.compact.reject(&:empty?).uniq

  if barcodes.any? && Spree::Variant.with_deleted.where(barcode: barcodes).exists?
    print "."
    skipped += 1
    next
  end

  first = variants.first
  brand = (v_row || first)['brand'].to_s.strip

  # Product name: prefer clean name from V row, fall back to first variant name
  product_name = v_row ? v_row['ItemName'].to_s.strip : first['ItemName'].to_s.strip
  product_name = first['ItemName'].to_s.strip if product_name.blank?

  category_key = (v_row || first)['ItmsGrp1'].to_s.strip

  print "\n[#{idx + 1}/#{total}] #{product_name} (#{variants.size} variants)"

  # Description: store URL from V row if available
  description = nil
  if v_row && v_row['DESCRIPTION'].present?
    desc_url = v_row['DESCRIPTION'].strip
    description = "<p><a href=\"#{desc_url}\" target=\"_blank\" rel=\"noopener\">View full product description</a></p>"
  end

  # Slug
  slug_base = product_name.parameterize.truncate(80, omission: '')
  slug = slug_base
  if Spree::Product.with_deleted.find_by(slug: slug)
    slug = "#{slug_base}-ga"
    slug = "#{slug_base}-ga2" if Spree::Product.with_deleted.find_by(slug: slug)
  end

  # Taxons
  brand_taxon    = brand_taxons[brand]
  category_taxon = category_taxons[category_key]
  taxons = [brand_taxon, category_taxon].compact.uniq

  # Determine option types used
  ot1_name = variants.map { |r| r['VARIANT 1'] }.compact.reject { |v| v == '0' }.first
  ot2_name = variants.map { |r| r['VARIANT 2'] }.compact.reject { |v| v == '0' }.first
  has_ot1  = ot1_name.present?
  has_ot2  = ot2_name.present?

  ot1 = has_ot1 ? find_or_create_ot(option_type_cache, ot1_name) : nil
  ot2 = has_ot2 ? find_or_create_ot(option_type_cache, ot2_name) : nil

  # Collect all unique image URLs (V row first, then variants)
  all_image_urls = []
  all_image_urls += image_urls_from_row(v_row) if v_row
  variants.each { |r| all_image_urls += image_urls_from_row(r) }
  all_image_urls = all_image_urls.uniq

  begin
    ActiveRecord::Base.transaction do
      price = parse_price(first['PRICE'])
      price = parse_price(variants.map { |r| r['PRICE'] }.find(&:present?)) if price.zero?

      product = Spree::Product.create!(
        name:              product_name,
        slug:              slug,
        description:       description,
        price:             price,
        currency:          CURRENCY,
        shipping_category: shipping_category,
        status:            'active',
        stores:            [store]
      )
      product.option_types << ot1 if ot1
      product.option_types << ot2 if ot2
      product.taxons = taxons if taxons.any?

      # Attach all product images to master variant
      attached = {}
      all_image_urls.each do |img_url|
        next if attached[img_url]
        ok = attach_image(product.master, img_url)
        attached[img_url] = true if ok
        print ok ? " ✓" : " ✗"
      end

      # Create variants
      variants.each do |row|
        sku     = row['SKU']
        barcode = row['BARCODE'].presence
        price_v = parse_price(row['PRICE'])
        weight  = row['BOXWeight'].to_f

        ov1_val = row['Attribute 1'].presence
        ov2_val = row['Attribute 2'].presence
        ov1_val = nil if ov1_val == '0'
        ov2_val = nil if ov2_val == '0'

        if !has_ot1 && !has_ot2
          product.master.update!(
            sku:     sku,
            barcode: barcode,
            weight:  weight > 0 ? weight : nil
          )
        else
          ovs = []
          ovs << find_or_build_option_value(ot1, ov1_val) if ot1 && ov1_val.present?
          ovs << find_or_build_option_value(ot2, ov2_val) if ot2 && ov2_val.present?

          # Skip stray rows that have no option values in an option-based product
          next if ovs.empty?

          v = Spree::Variant.new(
            product:  product,
            sku:      sku,
            barcode:  barcode,
            price:    price_v > 0 ? price_v : price,
            currency: CURRENCY,
            weight:   weight > 0 ? weight : nil
          )
          v.option_values = ovs
          v.save!
        end
      end
    end
    imported += 1
  rescue => e
    puts "\n  ✗ ERROR: #{e.message}"
    puts "    " + e.backtrace.first(3).join("\n    ")
    errors += 1
  end
end

elapsed = (Time.current - start_at).round
puts "\n\n#{'=' * 60}"
puts "Import complete in #{elapsed}s"
puts "  Imported : #{imported}"
puts "  Skipped  : #{skipped} (barcode already exists)"
puts "  Errors   : #{errors}"
puts "  Total    : #{total}"
