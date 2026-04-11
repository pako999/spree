# frozen_string_literal: true
# Import Duotone Windsurf DTW24 (Sails, Booms, Masts, Extensions, Tuning Parts)
# Source: https://docs.google.com/spreadsheets/d/1FmvOeLI-kAwTi1ekYIYieFBvwZlj7o7FHr3LUPyQg_Y
# Images: must be pre-staged in /rails/tmp/dtw24_images/ (local files, not URLs)
# Dedup: skip product if ANY variant barcode already exists in DB (incl. soft-deleted)
#
# IMPORTANT: ALWAYS run with --reuse. Plain `kamal app exec` spins up a
# throwaway container that can terminate before Active Storage's after_commit
# file-write hook runs, leaving blob records in DB while the bytes never
# actually land on disk. Use attach_dtw24_images.rb to repair if that happens.
#
# Run: kamal app exec --reuse "bin/rails runner /rails/script/import_duotone_windsurf_dtw24.rb"

require 'csv'
require 'open-uri'

CURRENCY = 'EUR'
CSV_URL  = 'https://docs.google.com/spreadsheets/d/1FmvOeLI-kAwTi1ekYIYieFBvwZlj7o7FHr3LUPyQg_Y/export?format=csv'
IMAGE_DIR = '/rails/tmp/dtw24_images'

# PIM Category Name -> categories taxon permalink
CATEGORY_MAP = {
  'Masts'              => 'categories/windsurf/windsurf-gear/windsurf-mast',
  'Booms'              => 'categories/windsurf/windsurf-gear/windsurf-boom',
  'Sails'              => 'categories/windsurf/windsurf-sails/windsurfing-sails',
  'Extensions & Bases' => 'categories/windsurf/windsurf-gear/windsurf-extension',
  'Tuning Parts'       => 'categories/windsurf/windsurf-accessories/windsurf-spare-parts'
}.freeze

# Optional brand subtaxons by category (leave nil to use base brand taxon only)
BRAND_SUB_MAP = {
  'Masts' => 'brands/duotone-windsurfing/masts',
  'Booms' => 'brands/duotone-windsurfing/booms',
  'Sails' => 'brands/duotone-windsurfing/sails'
}.freeze

def attach_local_image(record, filename)
  path = File.join(IMAGE_DIR, filename)
  unless File.exist?(path)
    print " [missing: #{filename}]"
    return false
  end
  ext = File.extname(filename).downcase
  ctype = case ext
          when '.png'  then 'image/png'
          when '.webp' then 'image/webp'
          when '.gif'  then 'image/gif'
          else 'image/jpeg'
          end
  # Read the full file into a StringIO so Active Storage can buffer it safely
  # (plain File handles get closed before the upload completes on fast paths)
  io = StringIO.new(File.binread(path))
  record.images.create!(attachment: { io: io, filename: filename, content_type: ctype })
  true
rescue => e
  print " [attach err: #{e.message.truncate(60)}]"
  false
end

def find_or_build_option_value(option_type, raw_name)
  normalized = raw_name.to_s.parameterize
  return nil if normalized.blank?
  Spree::OptionValue.find_by(option_type_id: option_type.id, name: normalized) ||
    Spree::OptionValue.create!(option_type: option_type, name: raw_name, presentation: raw_name)
end

def slugify(text)
  text.to_s.downcase.gsub(/[^a-z0-9]+/, '-').gsub(/^-|-$/, '')
end

puts "Downloading CSV..."
csv_data = URI.open(CSV_URL, 'User-Agent' => 'Mozilla/5.0').read.force_encoding('UTF-8')
rows_by_pid = {}
CSV.parse(csv_data, headers: true, encoding: 'UTF-8') do |row|
  pid = row['Product Id']
  next if pid.blank?
  rows_by_pid[pid] ||= []
  rows_by_pid[pid] << row.to_h.transform_values { |v| v&.encode('UTF-8', invalid: :replace, undef: :replace) }
end
puts "Total unique products in sheet: #{rows_by_pid.size}"

shipping_category = Spree::ShippingCategory.find(1)
store             = Spree::Store.find(2)

size_ot  = Spree::OptionType.find_or_create_by!(name: 'size')  { |o| o.presentation = 'Size'  }
color_ot = Spree::OptionType.find_or_create_by!(name: 'color') { |o| o.presentation = 'Color' }

brand_taxon = Spree::Taxon.find_by!(permalink: 'brands/duotone-windsurfing')
brand_sub_taxons = BRAND_SUB_MAP.transform_values { |p| Spree::Taxon.find_by(permalink: p) }
category_taxons  = CATEGORY_MAP.transform_values { |p| Spree::Taxon.find_by(permalink: p) }

imported = 0
skipped  = 0
errors   = 0
total    = rows_by_pid.size
start_at = Time.current

rows_by_pid.each_with_index do |(pid, rows), idx|
  first = rows.first
  title = first['BAMMAMItemName']
  pim_category = first['PIM Category Name']

  barcodes = rows.map { |r| r['Variant SKU'] }.compact.reject(&:empty?).uniq

  # SKIP if any barcode already exists (incl. soft-deleted)
  if barcodes.any? && Spree::Variant.with_deleted.where(barcode: barcodes).exists?
    print "."
    skipped += 1
    next
  end

  # Build slug: product_id + slugified name, strip collisions
  base_slug = slugify("#{title}-#{pid}")
  slug = base_slug
  if Spree::Product.with_deleted.find_by(slug: slug)
    slug = "#{base_slug}-dtw24"
  end

  # Build description from Description_en + KeyFeatures_en + Features_en
  desc_parts = []
  desc_parts << first['Description_en'].to_s.strip if first['Description_en'].present?
  if first['KeyFeatures_en'].present?
    kf = first['KeyFeatures_en'].to_s.strip
    desc_parts << "<h3>Key Features</h3><ul>" + kf.split(/[\r\n]+/).map(&:strip).reject(&:empty?).map { |l| "<li>#{CGI.escapeHTML(l.sub(/^[-•*]\s*/, ''))}</li>" }.join + "</ul>"
  end
  if first['Features_en'].present?
    desc_parts << "<h3>Features</h3><p>#{CGI.escapeHTML(first['Features_en'].to_s.strip)}</p>"
  end
  description = desc_parts.join("\n")

  # Detect options: Option1 Name = Color (Vari column), Option2 Name = Size (Variant 2 column)
  opt1_name = first['Option1 Name']  # "Color"
  opt2_name = first['Option2 Name']  # "Size"

  # The Vari column often contains "C99:random" which is a color code — skip it for distinctness
  vari_values    = rows.map { |r| r['Vari'].to_s.strip }.reject(&:empty?).uniq
  variant2_values = rows.map { |r| r['Variant 2'].to_s.strip }.reject(&:empty?).uniq

  has_color = opt1_name.to_s.downcase.include?('color') && vari_values.any? && vari_values != ['C99:random']
  has_size  = opt2_name.to_s.downcase.include?('size')  && variant2_values.any?
  # If all colors are "C99:random" (generic), treat as no color option
  has_color = false if vari_values.all? { |v| v == 'C99:random' }

  color_cache = {}
  size_cache  = {}
  vari_values.each    { |v| color_cache[v] = find_or_build_option_value(color_ot, v) } if has_color
  variant2_values.each { |v| size_cache[v]  = find_or_build_option_value(size_ot,  v) } if has_size

  has_variants = has_color || has_size

  print "\n[#{idx + 1}/#{total}] #{title} [#{pim_category}] (#{rows.size} variants)"

  product = nil
  image_filenames = []
  begin
    ActiveRecord::Base.transaction do
      product = Spree::Product.create!(
        name:              title,
        slug:              slug,
        description:       description.presence,
        price:             first['PRICE'].to_f,
        currency:          CURRENCY,
        shipping_category: shipping_category,
        status:            'active',
        stores:            [store]
      )

      product.option_types << color_ot if has_color
      product.option_types << size_ot  if has_size

      # Assign taxons: brand + brand subcategory + category
      tx = [brand_taxon]
      tx << brand_sub_taxons[pim_category] if brand_sub_taxons[pim_category]
      tx << category_taxons[pim_category] if category_taxons[pim_category]
      product.taxons = tx.compact.uniq

      rows.each do |row|
        barcode   = row['Variant SKU']
        price     = row['PRICE'].to_f
        opt1_val  = row['Vari'].to_s.strip
        opt2_val  = row['Variant 2'].to_s.strip
        image_src = row['Image Src'].to_s.strip

        if !has_variants
          product.master.update!(sku: barcode, barcode: barcode)
        else
          ovs = []
          ovs << color_cache[opt1_val] if has_color && opt1_val.present? && color_cache[opt1_val]
          ovs << size_cache[opt2_val]  if has_size  && opt2_val.present? && size_cache[opt2_val]

          if ovs.empty?
            product.master.update!(sku: barcode, barcode: barcode)
          else
            variant = Spree::Variant.new(
              product: product,
              sku: barcode,
              barcode: barcode,
              price: price,
              currency: CURRENCY
            )
            variant.option_values = ovs
            variant.save!
          end
        end

        # Collect unique image filenames — attach OUTSIDE the transaction so
        # image errors can't roll back the product create.
        next if image_src.blank?
        image_src.split(';').map(&:strip).reject(&:empty?).each do |fn|
          image_filenames << fn unless image_filenames.include?(fn)
        end
      end
    end

    # Attach images outside the transaction (per-image failures won't rollback)
    image_filenames.each do |fn|
      ok = attach_local_image(product.master, fn)
      print ok ? ' ✓' : ' ✗'
    end

    imported += 1
  rescue => e
    puts "\n  ✗ ERROR: #{e.message}"
    puts "    " + e.backtrace.first(3).join("\n    ")
    errors += 1
  end
end

elapsed = (Time.current - start_at).round
puts "\n\n#{'='*60}"
puts "Import complete in #{elapsed}s"
puts "  Imported : #{imported}"
puts "  Skipped  : #{skipped} (barcode already exists)"
puts "  Errors   : #{errors}"
puts "  Total    : #{total}"
