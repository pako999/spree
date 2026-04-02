# frozen_string_literal: true
# Import Duotone Windsurfing products from Google Sheets CSV
# Dedup: skip product if ANY variant barcode already exists in DB (incl. soft-deleted)
# Run: bin/kamal app exec --reuse "bin/rails runner /rails/script/import_duotone_windsurf.rb"

require 'csv'
require 'net/http'
require 'uri'
require 'tempfile'
require 'open-uri'

CURRENCY = 'EUR'
CSV_URL  = 'https://docs.google.com/spreadsheets/d/1lF1tsddvCi55SegxWlXDxK4EiMifeSfxSOVYSjQhaOw/export?format=csv'

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

# This sheet uses Option1=Size, Option2=Color, Option3=Size (some variants)
# We'll map all distinct option names dynamically
size_ot  = Spree::OptionType.find_or_create_by!(name: 'size')  { |o| o.presentation = 'Size'  }
color_ot = Spree::OptionType.find_or_create_by!(name: 'color') { |o| o.presentation = 'Color' }

puts "Store: #{store.name}"

imported = 0
skipped  = 0
errors   = 0
total    = rows_by_handle.size
start_at = Time.current

rows_by_handle.each_with_index do |(handle, rows), idx|
  first    = rows.first
  title    = first['Title']

  barcodes = rows.map { |r| r['Variant Barcode'] }.compact.reject(&:empty?).uniq
  skus     = rows.map { |r| r['Variant SKU'] }.compact.reject(&:empty?).uniq

  # Skip if any barcode already exists
  if barcodes.any? && Spree::Variant.with_deleted.where(barcode: barcodes).exists?
    print "."
    skipped += 1
    next
  end

  # Fallback: skip by SKU
  if skus.any? && Spree::Variant.with_deleted.where(sku: skus).exists?
    print "."
    skipped += 1
    next
  end

  slug = handle.sub(/-\d{4}$/, '')
  slug = "#{slug}-dtw" if Spree::Product.with_deleted.find_by(slug: slug)

  # Detect which options are used
  opt1_name = rows.map { |r| r['Option1 Name'] }.compact.first
  opt2_name = rows.map { |r| r['Option2 Name'] }.compact.first
  opt3_name = rows.map { |r| r['Option3 Name'] }.compact.first

  has_opt1 = opt1_name.present? && rows.any? { |r| r['Option1 Value'].present? }
  has_opt2 = opt2_name.present? && rows.any? { |r| r['Option2 Value'].present? }
  has_opt3 = opt3_name.present? && rows.any? { |r| r['Option3 Value'].present? }

  # Map option names to our option types
  def ot_for(name, size_ot, color_ot)
    return color_ot if name.to_s.downcase == 'color'
    size_ot  # Size, Volume, or any other dimension
  end

  ot1 = has_opt1 ? ot_for(opt1_name, size_ot, color_ot) : nil
  ot2 = has_opt2 ? ot_for(opt2_name, size_ot, color_ot) : nil
  ot3 = has_opt3 ? ot_for(opt3_name, size_ot, color_ot) : nil

  # Build option value caches
  ov1_cache = {}
  ov2_cache = {}
  ov3_cache = {}
  rows.map { |r| r['Option1 Value'] }.compact.uniq.each { |v| ov1_cache[v] = find_or_build_option_value(ot1, v) } if has_opt1
  rows.map { |r| r['Option2 Value'] }.compact.uniq.each { |v| ov2_cache[v] = find_or_build_option_value(ot2, v) } if has_opt2
  rows.map { |r| r['Option3 Value'] }.compact.uniq.each { |v| ov3_cache[v] = find_or_build_option_value(ot3, v) } if has_opt3

  has_variants = has_opt1 || has_opt2 || has_opt3

  print "\n[#{idx + 1}/#{total}] #{title} (#{rows.size} variants)"

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

      used_ots = [ot1, ot2, ot3].compact.uniq
      used_ots.each { |ot| product.option_types << ot }

      attached_images = {}

      rows.each do |row|
        sku         = row['Variant SKU']
        barcode     = row['Variant Barcode']
        price       = row['Variant Price'].to_f
        weight_kg   = row['Variant Grams'].to_f / 1000.0
        opt1_val    = row['Option1 Value']
        opt2_val    = row['Option2 Value']
        opt3_val    = row['Option3 Value']
        image_src   = row['Image Src']
        variant_img = row['Variant Image']

        if !has_variants
          product.master.update!(sku: sku, barcode: barcode, weight: weight_kg)
        else
          ovs = []
          ovs << ov1_cache[opt1_val] if has_opt1 && opt1_val.present? && ov1_cache[opt1_val]
          ovs << ov2_cache[opt2_val] if has_opt2 && opt2_val.present? && ov2_cache[opt2_val]
          ovs << ov3_cache[opt3_val] if has_opt3 && opt3_val.present? && ov3_cache[opt3_val]

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
