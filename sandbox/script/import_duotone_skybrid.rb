# frozen_string_literal: true
# Duotone Skybrid D/LAB import from Google Sheets CSV (Shopify format)
#
# Sheet: https://docs.google.com/spreadsheets/d/1sat_a6a6NBa3lm1AO3P2956oGK0Sh86jL2uP_R-f14Y
# 1 product / 5 size variants — Duotone Skybrid D/LAB iFoilboard @ €22,399
# Prices in CSV are direct EUR values.
# Skip if ANY variant EAN/barcode already exists in the DB.
#
# NOTE: The Handle column has a nil/blank header in this sheet — using row.fields.first
#
# Run:
#   bin/kamal app exec --reuse "bin/rails runner /rails/script/import_duotone_skybrid.rb"

require 'csv'
require 'net/http'
require 'uri'
require 'tempfile'
require 'open-uri'

CURRENCY = 'EUR'
STORE_ID = 2
CSV_URL  = 'https://docs.google.com/spreadsheets/d/1sat_a6a6NBa3lm1AO3P2956oGK0Sh86jL2uP_R-f14Y/export?format=csv'

CATEGORY_TAG_MAP = {
  'Wing'               => 'categories/wingfoil/wings',
  'Parawing'           => 'categories/kitesurfing/kites/parawings',
  'Front Wing'         => 'categories/wingfoil/wing-foils',
  'Back Wing'          => 'categories/wingfoil/wing-foils',
  'Foil Wing Set'      => 'categories/wingfoil/wing-foils',
  'Mast'               => 'categories/wingfoil/wing-foils',
  'Fusepart'           => 'categories/wingfoil/wing-foils',
  'Foilboard'          => 'categories/wingfoil/wing-boards',
  'iFoilboard'         => 'categories/wingfoil/wing-boards',
  'Gearbag & Boardbag' => 'categories/wingfoil/wing-accessories',
  'Board Accessory'    => 'categories/wingfoil/wing-accessories',
}.freeze

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
      req['Referer']    = 'https://www.boards-and-more.com/'
      http.request(req)
    end
    case res
    when Net::HTTPSuccess
      return nil if res.body.to_s.empty?
      ext  = File.extname(uri.path).split('?').first.downcase.presence || '.jpg'
      ext  = '.jpg' unless ['.jpg', '.jpeg', '.png', '.webp', '.gif'].include?(ext)
      tmpf = Tempfile.new(['img', ext])
      tmpf.binmode
      tmpf.write(res.body)
      tmpf.rewind
      return tmpf
    when Net::HTTPRedirection
      uri = URI.parse(res['location'])
    else
      puts " [HTTP #{res.code}]"
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
  ext   = File.extname(fname).downcase
  ctype = case ext
          when '.png'  then 'image/png'
          when '.webp' then 'image/webp'
          when '.gif'  then 'image/gif'
          else 'image/jpeg'
          end
  record.images.create!(attachment: { io: tmpf, filename: fname, content_type: ctype })
  true
rescue => e
  puts " [attach err: #{e.message.truncate(60)}]"
  false
end

puts "Downloading CSV..."
csv_data = URI.open(CSV_URL, 'User-Agent' => 'Mozilla/5.0').read.force_encoding('UTF-8')

# NOTE: Handle column header is nil in this sheet — use fields.first to get the value
rows_by_handle = {}
CSV.parse(csv_data, headers: true, encoding: 'UTF-8') do |row|
  handle = row.fields.first  # nil-keyed column = first field
  next if handle.blank?
  rows_by_handle[handle] ||= []
  rows_by_handle[handle] << row.to_h.transform_values { |v| v&.encode('UTF-8', invalid: :replace, undef: :replace) }
end
puts "Unique products in sheet: #{rows_by_handle.size}"

shipping_category = Spree::ShippingCategory.find(1)
store             = Spree::Store.find(STORE_ID)
color_ot = Spree::OptionType.find_or_create_by!(name: 'color') { |o| o.presentation = 'Color' }
size_ot  = Spree::OptionType.find_or_create_by!(name: 'size')  { |o| o.presentation = 'Size'  }

brand_taxon    = Spree::Taxon.find_by!(permalink: 'brands/duotone-wing-foiling')
wingfoil_taxon = Spree::Taxon.find_by!(permalink: 'categories/wingfoil')
category_taxons = CATEGORY_TAG_MAP.transform_values { |p| Spree::Taxon.find_by(permalink: p) }

def find_or_build_option_value(option_type, raw_name)
  normalized = raw_name.to_s.parameterize
  Spree::OptionValue.find_by(option_type_id: option_type.id, name: normalized) ||
    Spree::OptionValue.create!(option_type: option_type, name: raw_name, presentation: raw_name)
end

imported = 0
skipped  = 0
errors   = 0
total    = rows_by_handle.size
start_at = Time.current

rows_by_handle.each_with_index do |(handle, rows), idx|
  first    = rows.first
  title    = first['Title']
  barcodes = rows.map { |r| r['Variant Barcode'] }.compact.reject(&:empty?).uniq

  # Skip if ANY barcode/EAN already exists
  if barcodes.any? && Spree::Variant.with_deleted.where(barcode: barcodes).exists?
    puts "\n[#{idx + 1}/#{total}] SKIP #{title} (EAN exists)"
    skipped += 1
    next
  end

  print "\n[#{idx + 1}/#{total}] #{title} (#{rows.size} variants)"

  # Determine sub-category from category_level_2 tag
  tags_str = first['Tags'].to_s
  category_taxon = nil
  CATEGORY_TAG_MAP.each_key do |hint|
    if tags_str.include?("category_level_2_#{hint}")
      category_taxon = category_taxons[hint]
      break
    end
  end
  category_taxon ||= wingfoil_taxon

  # Build slug — use handle (first field), strip year suffix, avoid collisions
  slug = handle.to_s.sub(/-\d{4}$/, '').gsub(/[^a-z0-9\-]/, '-').squeeze('-').gsub(/^-|-$/, '')
  slug = 'duotone-skybrid-dlab' if slug.blank?
  if Spree::Product.with_deleted.find_by(slug: slug)
    slug = "#{slug}-dtf"
  end

  has_color = rows.any? { |r| r['Option1 Name'] == 'Color' && r['Option1 Value'].present? }
  has_size  = rows.any? { |r| r['Option2 Name'] == 'Size'  && r['Option2 Value'].present? }

  # Also check Option1 for size (some sheets put size in Option1)
  unless has_size
    has_size = rows.any? { |r| r['Option1 Name'] == 'Size' && r['Option1 Value'].present? }
    if has_size
      # Size is in Option1 slot
      size_in_opt1 = true
    end
  end

  color_values = {}
  size_values  = {}

  if has_color
    rows.map { |r| r['Option1 Value'] }.compact.uniq.each { |v| color_values[v] = find_or_build_option_value(color_ot, v) }
  end

  if has_size
    if defined?(size_in_opt1) && size_in_opt1
      rows.map { |r| r['Option1 Value'] }.compact.uniq.each { |v| size_values[v] = find_or_build_option_value(size_ot, v) }
    else
      rows.map { |r| r['Option2 Value'] }.compact.uniq.each { |v| size_values[v] = find_or_build_option_value(size_ot, v) }
    end
  end

  base_price = first['Variant Price'].to_f

  begin
    ActiveRecord::Base.transaction do
      product = Spree::Product.create!(
        name:              title,
        slug:              slug,
        description:       first['Body (HTML)'].presence,
        price:             base_price,
        currency:          CURRENCY,
        shipping_category: shipping_category,
        status:            'active',
        stores:            [store]
      )
      product.option_types << color_ot if has_color
      product.option_types << size_ot  if has_size

      taxons_to_assign = [brand_taxon, wingfoil_taxon]
      taxons_to_assign << category_taxon if category_taxon && category_taxon != wingfoil_taxon
      product.taxons = taxons_to_assign.compact.uniq

      # Collect unique images ordered by Image Position
      image_rows = rows.select { |r| r['Image Src'].present? }
                       .sort_by { |r| r['Image Position'].to_i }
                       .uniq { |r| r['Image Src'] }
      attached_images = {}

      image_rows.each do |row|
        src = row['Image Src']
        next if attached_images[src]
        ok = attach_image(product.master, src)
        attached_images[src] = true if ok
        print ok ? " ✓" : " ✗"
      end

      rows.each do |row|
        sku       = row['Variant SKU']
        barcode   = row['Variant Barcode']
        price     = row['Variant Price'].to_f
        weight_kg = row['Variant Grams'].to_f / 1000.0

        # Handle size-in-opt1 vs normal layout
        if defined?(size_in_opt1) && size_in_opt1
          opt_size_val = row['Option1 Value']
          opt_color_val = nil
        else
          opt_color_val = row['Option1 Value']
          opt_size_val  = row['Option2 Value']
        end

        if !has_color && !has_size
          product.master.update!(sku: sku, barcode: barcode, weight: weight_kg)
        else
          ovs = []
          ovs << color_values[opt_color_val] if has_color && opt_color_val.present? && color_values[opt_color_val]
          ovs << size_values[opt_size_val]   if has_size  && opt_size_val.present?  && size_values[opt_size_val]

          variant = Spree::Variant.new(
            product:  product,
            sku:      sku,
            barcode:  barcode,
            price:    price,
            currency: CURRENCY,
            weight:   weight_kg
          )
          variant.option_values = ovs
          variant.save!
        end
      end
    end

    imported += 1
  rescue => e
    puts "\n  ✗ ERROR: #{e.message}"
    puts "    " + e.backtrace.first(2).join("\n    ")
    errors += 1
  end
end

elapsed = (Time.current - start_at).round
puts "\n\n#{'=' * 60}"
puts "Duotone Skybrid D/LAB import complete in #{elapsed}s"
puts "  Imported : #{imported}"
puts "  Skipped  : #{skipped} (EAN already exists)"
puts "  Errors   : #{errors}"
puts "  Total    : #{total}"
