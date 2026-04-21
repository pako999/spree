# frozen_string_literal: true
# Import Duotone Windsurfing 2026 boards & sails from Google Sheets (Shopify-format CSV)
# Source: https://docs.google.com/spreadsheets/d/1fNVzmPICVpOb6CnpqFMAT-s8VueeDyZajXL0r8Qf5RQ
# Images: downloaded from boards-and-more CDN over HTTPS
# Dedup: skip product if ANY variant barcode OR SKU already exists in DB (incl. soft-deleted)
#
# NOTE: run with --reuse so Active Storage file writes complete before the container exits.
# Run: kamal app exec --reuse "bin/rails runner /rails/script/import_dtw26_windsurf.rb"

require 'csv'
require 'net/http'
require 'uri'
require 'open-uri'

CURRENCY = 'EUR'
CSV_URL  = 'https://docs.google.com/spreadsheets/d/1fNVzmPICVpOb6CnpqFMAT-s8VueeDyZajXL0r8Qf5RQ/export?format=csv'

CATEGORY_MAP = {
  'Boards' => 'categories/windsurf/windsurf-boards',
  'Sails'  => 'categories/windsurf/windsurf-sails/windsurfing-sails'
}.freeze

# ─── Helpers ────────────────────────────────────────────────────────────────

def download_image(url_str)
  uri = URI.parse(url_str)
  tries = 0
  loop do
    tries += 1
    return nil if tries > 5
    res = Net::HTTP.start(uri.host, uri.port,
                          use_ssl: uri.scheme == 'https',
                          open_timeout: 10, read_timeout: 30) do |http|
      req = Net::HTTP::Get.new(uri)
      req['User-Agent'] = 'Mozilla/5.0'
      req['Accept']     = 'image/*,*/*;q=0.8'
      req['Referer']    = 'https://www.boards-and-more.com/'
      http.request(req)
    end
    case res
    when Net::HTTPSuccess
      return nil if res.body.to_s.empty?
      # StringIO so the bytes are buffered in memory — avoids premature file-close issues
      StringIO.new(res.body.dup)
    when Net::HTTPRedirection
      uri = URI.parse(res['location'])
      next
    else
      return nil
    end
  end
rescue => e
  print " [dl:#{e.message[0, 40]}]"
  nil
end

def attach_image(record, url_str)
  io = download_image(url_str)
  return false unless io
  fname = File.basename(URI.parse(url_str).path).split('?').first
  ext   = File.extname(fname).downcase
  ctype = case ext
          when '.png'  then 'image/png'
          when '.webp' then 'image/webp'
          when '.gif'  then 'image/gif'
          else              'image/jpeg'
          end
  record.images.create!(attachment: { io: io, filename: fname, content_type: ctype })
  true
rescue => e
  print " [img:#{e.message[0, 50]}]"
  false
end

def find_or_build_option_value(option_type, raw_name)
  normalized = raw_name.to_s.parameterize
  return nil if normalized.empty?
  Spree::OptionValue.find_by(option_type_id: option_type.id, name: normalized) ||
    Spree::OptionValue.create!(option_type: option_type, name: raw_name, presentation: raw_name)
end

# ─── Load CSV ───────────────────────────────────────────────────────────────

puts "Downloading CSV from Google Sheets..."
csv_data = URI.open(CSV_URL, 'User-Agent' => 'Mozilla/5.0').read.force_encoding('UTF-8')

rows_by_handle = {}
CSV.parse(csv_data, headers: true, encoding: 'UTF-8') do |row|
  handle = row['Handle'].to_s.strip
  next if handle.empty?
  rows_by_handle[handle] ||= []
  rows_by_handle[handle] << row.to_h.transform_values { |v| v&.encode('UTF-8', invalid: :replace, undef: :replace) }
end
puts "Unique products in sheet: #{rows_by_handle.size}"

# ─── Spree setup ────────────────────────────────────────────────────────────

shipping_category = Spree::ShippingCategory.find(1)
store             = Spree::Store.find(2)

size_ot  = Spree::OptionType.find_or_create_by!(name: 'size')  { |o| o.presentation = 'Size'  }
color_ot = Spree::OptionType.find_or_create_by!(name: 'color') { |o| o.presentation = 'Color' }

brand_taxon     = Spree::Taxon.find_by(permalink: 'brands/duotone-windsurfing')
category_taxons = CATEGORY_MAP.transform_values { |p| Spree::Taxon.find_by(permalink: p) }

puts "Brand:       #{brand_taxon&.name || '⚠ NOT FOUND — products will be imported without brand taxon'}"
category_taxons.each { |k, v| puts "Category #{k.ljust(6)}: #{v&.name || '⚠ NOT FOUND'}" }
puts

# ─── Import loop ────────────────────────────────────────────────────────────

imported = 0
skipped  = 0
errors   = 0
total    = rows_by_handle.size
start_at = Time.current

rows_by_handle.each_with_index do |(handle, rows), idx|
  first = rows.first
  title = first['Title'].to_s.strip

  barcodes = rows.map { |r| r['Variant Barcode'].to_s.strip }.reject(&:empty?).uniq
  skus     = rows.map { |r| r['Variant SKU'].to_s.strip }.reject(&:empty?).uniq

  # ── Dedup: skip if any barcode or SKU already in DB (incl. soft-deleted) ──
  if barcodes.any? && Spree::Variant.with_deleted.where(barcode: barcodes).exists?
    print '.'
    skipped += 1
    next
  end
  if skus.any? && Spree::Variant.with_deleted.where(sku: skus).exists?
    print '.'
    skipped += 1
    next
  end

  # ── Slug: strip year suffix; append -2026 if collision ────────────────────
  slug = handle.sub(/-\d{4}$/, '')
  slug = "#{slug}-2026" if Spree::Product.with_deleted.find_by(slug: slug)

  # ── Option types ──────────────────────────────────────────────────────────
  opt1_name = rows.map { |r| r['Option1 Name'] }.compact.first.to_s
  opt2_name = rows.map { |r| r['Option2 Name'] }.compact.first.to_s

  has_opt1 = opt1_name.length > 0 && rows.any? { |r| r['Option1 Value'].to_s.strip.length > 0 }
  has_opt2 = opt2_name.length > 0 && rows.any? { |r| r['Option2 Value'].to_s.strip.length > 0 }

  ot1 = has_opt1 ? (opt1_name.downcase == 'color' ? color_ot : size_ot) : nil
  ot2 = has_opt2 ? (opt2_name.downcase == 'color' ? color_ot : size_ot) : nil

  ov1_cache = {}
  ov2_cache = {}
  if has_opt1
    rows.map { |r| r['Option1 Value'].to_s.strip }.reject(&:empty?).uniq.each do |v|
      ov1_cache[v] = find_or_build_option_value(ot1, v)
    end
  end
  if has_opt2
    rows.map { |r| r['Option2 Value'].to_s.strip }.reject(&:empty?).uniq.each do |v|
      ov2_cache[v] = find_or_build_option_value(ot2, v)
    end
  end

  pim_category = first['Product Category'].to_s.strip
  base_price   = first['Variant Price'].to_f

  print "\n[#{idx + 1}/#{total}] #{title} [#{pim_category}] (#{rows.size} rows)"

  product          = nil
  images_to_attach = []  # [[record, url], ...]

  begin
    ActiveRecord::Base.transaction do
      product = Spree::Product.create!(
        name:              title,
        slug:              slug,
        description:       first['Body (HTML)'].to_s.presence,
        meta_title:        first['SEO Title'].to_s.presence,
        price:             base_price,
        currency:          CURRENCY,
        shipping_category: shipping_category,
        status:            'active',
        stores:            [store]
      )

      [ot1, ot2].compact.uniq.each { |ot| product.option_types << ot }

      taxons = [brand_taxon, category_taxons[pim_category]].compact.uniq
      product.taxons = taxons unless taxons.empty?

      attached_image_urls = {}

      rows.each do |row|
        sku         = row['Variant SKU'].to_s.strip
        barcode     = row['Variant Barcode'].to_s.strip
        price       = row['Variant Price'].to_f
        cost        = row['Cost per item'].to_f
        weight_kg   = row['Variant Grams'].to_f / 1000.0
        opt1_val    = row['Option1 Value'].to_s.strip
        opt2_val    = row['Option2 Value'].to_s.strip
        image_src   = row['Image Src'].to_s.strip
        variant_img = row['Variant Image'].to_s.strip

        ovs = []
        ovs << ov1_cache[opt1_val] if has_opt1 && opt1_val.length > 0 && ov1_cache[opt1_val]
        ovs << ov2_cache[opt2_val] if has_opt2 && opt2_val.length > 0 && ov2_cache[opt2_val]

        if ovs.empty?
          product.master.update!(sku: sku, barcode: barcode, weight: weight_kg, cost_price: cost.positive? ? cost : nil)
        else
          variant = Spree::Variant.new(
            product:    product,
            sku:        sku,
            barcode:    barcode,
            price:      price.positive? ? price : base_price,
            currency:   CURRENCY,
            weight:     weight_kg,
            cost_price: cost.positive? ? cost : nil
          )
          variant.option_values = ovs
          variant.save!

          # Variant-specific image (colour photo) — deduplicated by URL
          if variant_img.length > 0 && !attached_image_urls[variant_img]
            images_to_attach << [variant, variant_img]
            attached_image_urls[variant_img] = true
          end
        end

        # Main product image (Image Src, position 1 row only)
        if image_src.length > 0 && !attached_image_urls[image_src]
          images_to_attach << [product.master, image_src]
          attached_image_urls[image_src] = true
        end
      end
    end

    # ── Attach images outside transaction — download failures won't rollback ─
    images_to_attach.each do |record, url|
      ok = attach_image(record, url)
      print ok ? ' ✓' : ' ✗'
    end

    imported += 1
  rescue => e
    puts "\n  ✗ ERROR: #{e.message}"
    puts '    ' + e.backtrace.first(3).join("\n    ")
    errors += 1
  end
end

elapsed = (Time.current - start_at).round
puts "\n\n#{'=' * 60}"
puts "Import complete in #{elapsed}s"
puts "  Imported : #{imported}"
puts "  Skipped  : #{skipped}  (barcode/SKU already in DB)"
puts "  Errors   : #{errors}"
puts "  Total    : #{total}"
