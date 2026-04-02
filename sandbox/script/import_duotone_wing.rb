# frozen_string_literal: true
# Import Duotone Wing Foiling products from Google Sheets CSV
# Dedup: skip if ANY variant barcode already exists in DB (including soft-deleted)
# Run: bin/kamal app exec --reuse "bin/rails runner /rails/script/import_duotone_wing.rb"

require 'csv'
require 'net/http'
require 'uri'
require 'tempfile'
require 'open-uri'

CURRENCY = 'EUR'
CSV_URL  = 'https://docs.google.com/spreadsheets/d/1nK_RowVZP5KDYU1WKjIyJGeOPgVJm-uIspuXPcQjOS0/export?format=csv'

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
      req['Referer']    = 'https://www.duotonesports.com/'
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

def find_or_build_option_value(option_type, raw_name)
  normalized = raw_name.to_s.parameterize
  Spree::OptionValue.find_by(option_type_id: option_type.id, name: normalized) ||
    Spree::OptionValue.create!(option_type: option_type, name: raw_name, presentation: raw_name)
end

puts "Downloading CSV..."
csv_data = URI.open(CSV_URL, 'User-Agent' => 'Mozilla/5.0').read.force_encoding('UTF-8')
rows_by_handle = {}
CSV.parse(csv_data, headers: true, encoding: 'UTF-8') do |row|
  handle = row['Handle']
  next if handle.blank?
  rows_by_handle[handle] ||= []
  rows_by_handle[handle] << row.to_h.transform_values { |v| v&.encode('UTF-8', invalid: :replace, undef: :replace) }
end
puts "Total unique products in sheet: #{rows_by_handle.size}"

shipping_category = Spree::ShippingCategory.find(1)
store             = Spree::Store.find(2)
color_ot = Spree::OptionType.find_or_create_by!(name: 'color') { |o| o.presentation = 'Color' }
size_ot  = Spree::OptionType.find_or_create_by!(name: 'size')  { |o| o.presentation = 'Size'  }

puts "Store: #{store.name}"

imported = 0
skipped  = 0
errors   = 0
total    = rows_by_handle.size
start_at = Time.current

rows_by_handle.each_with_index do |(handle, rows), idx|
  first  = rows.first
  title  = first['Title']

  # Collect all barcodes for this product
  barcodes = rows.map { |r| r['Variant Barcode'] }.compact.reject(&:empty?).uniq
  skus     = rows.map { |r| r['Variant SKU'] }.compact.reject(&:empty?).uniq

  # Skip if any barcode already exists (including soft-deleted variants)
  if barcodes.any? && Spree::Variant.with_deleted.where(barcode: barcodes).exists?
    print "."
    skipped += 1
    next
  end

  # Also skip by SKU as fallback
  if skus.any? && Spree::Variant.with_deleted.where(sku: skus).exists?
    print "."
    skipped += 1
    next
  end

  slug = handle.sub(/-\d{4}$/, '')
  slug = "#{slug}-duotone" if Spree::Product.with_deleted.find_by(slug: slug)

  print "\n[#{idx + 1}/#{total}] #{title} (#{rows.size} variants)"

  has_color = rows.any? { |r| r['Option1 Name'] == 'Color' && r['Option1 Value'].present? }
  has_size  = rows.any? { |r| r['Option2 Name'] == 'Size'  && r['Option2 Value'].present? }

  color_values = {}
  size_values  = {}
  rows.map { |r| r['Option1 Value'] }.compact.uniq.each { |v| color_values[v] = find_or_build_option_value(color_ot, v) } if has_color
  rows.map { |r| r['Option2 Value'] }.compact.uniq.each { |v| size_values[v]  = find_or_build_option_value(size_ot,  v) } if has_size

  begin
    product = nil
    ActiveRecord::Base.transaction do
      product = Spree::Product.create!(
        name:              title,
        slug:              slug,
        description:       first['Body (HTML)'].presence,
        price:             first['Variant Price'].to_f,
        currency:          CURRENCY,
        shipping_category: shipping_category,
        status:            'active',
        stores:            [store]
      )
      product.option_types << color_ot if has_color
      product.option_types << size_ot  if has_size

      attached_images = {}

      rows.each do |row|
        sku         = row['Variant SKU']
        barcode     = row['Variant Barcode']
        price       = row['Variant Price'].to_f
        weight_kg   = row['Variant Grams'].to_f / 1000.0
        opt1_val    = row['Option1 Value']
        opt2_val    = row['Option2 Value']
        image_src   = row['Image Src']
        variant_img = row['Variant Image']

        if !has_color && !has_size
          product.master.update!(sku: sku, barcode: barcode, weight: weight_kg)
        else
          ovs = []
          ovs << color_values[opt1_val] if has_color && opt1_val.present? && color_values[opt1_val]
          ovs << size_values[opt2_val]  if has_size  && opt2_val.present? && size_values[opt2_val]

          variant = Spree::Variant.new(product: product, sku: sku, barcode: barcode, price: price, currency: CURRENCY, weight: weight_kg)
          variant.option_values = ovs
          variant.save!

          if variant_img.present? && !attached_images[variant_img]
            ok = attach_image(variant, variant_img)
            attached_images[variant_img] = true if ok
            print ok ? " v✓" : " v✗"
          end
        end

        if image_src.present? && !attached_images[image_src]
          ok = attach_image(product.master, image_src)
          attached_images[image_src] = true if ok
          print ok ? " p✓" : " p✗"
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
puts "\n\n#{'='*60}"
puts "Import complete in #{elapsed}s"
puts "  Imported : #{imported}"
puts "  Skipped  : #{skipped} (barcode/SKU already exists)"
puts "  Errors   : #{errors}"
puts "  Total    : #{total}"
