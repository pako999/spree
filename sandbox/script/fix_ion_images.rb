# frozen_string_literal: true
# Fix ION product images:
#   1. Delete orphaned cloudflare blobs via raw SQL (no callbacks)
#   2. Re-download images from boards-and-more.com for products with missing images
#
# Run: bin/kamal app exec --reuse "bin/rails runner /rails/script/fix_ion_images.rb"

require 'csv'
require 'net/http'
require 'uri'
require 'tempfile'
require 'open-uri'

CSV_URL = 'https://docs.google.com/spreadsheets/d/1eo5WMuZzw6sM_4b40lOf6Dlw6IT0v59RU61xnyxbRz0/export?format=csv'

# -----------------------------------------------------------
# Step 1: Purge cloudflare blobs via raw SQL
# -----------------------------------------------------------
puts "Step 1: Purging cloudflare blobs..."
cloudflare_blob_ids = ActiveStorage::Blob.where(service_name: 'cloudflare').pluck(:id)
puts "  Found #{cloudflare_blob_ids.size} cloudflare blobs"

if cloudflare_blob_ids.any?
  # Delete attachments first (raw SQL bypasses broken purge callbacks)
  deleted_attachments = ActiveRecord::Base.connection.execute(
    "DELETE FROM active_storage_attachments WHERE blob_id IN (#{cloudflare_blob_ids.join(',')})"
  ).cmd_tuples
  # Also delete any variant records (representations) for these blobs
  deleted_variant_records = ActiveRecord::Base.connection.execute(
    "DELETE FROM active_storage_variant_records WHERE blob_id IN (#{cloudflare_blob_ids.join(',')})"
  ).cmd_tuples rescue 0
  # Delete blobs
  deleted_blobs = ActiveRecord::Base.connection.execute(
    "DELETE FROM active_storage_blobs WHERE id IN (#{cloudflare_blob_ids.join(',')})"
  ).cmd_tuples

  puts "  Deleted #{deleted_attachments} attachments, #{deleted_blobs} blobs"
end

# Also clean up spree_assets with no attachment
orphan_assets = ActiveRecord::Base.connection.execute(
  "DELETE FROM spree_assets WHERE id NOT IN (SELECT record_id FROM active_storage_attachments WHERE record_type = 'Spree::Asset')"
).cmd_tuples
puts "  Deleted #{orphan_assets} orphaned spree_assets"

# -----------------------------------------------------------
# Step 2: Re-download images for ION products with 0 images
# -----------------------------------------------------------
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

puts "\nStep 2: Re-downloading missing images..."
puts "  Downloading CSV..."
csv_data = URI.open(CSV_URL, 'User-Agent' => 'Mozilla/5.0').read.force_encoding('UTF-8')
rows_by_handle = {}
CSV.parse(csv_data, headers: true, encoding: 'UTF-8') do |row|
  handle = row['Handle']
  next if handle.blank?
  rows_by_handle[handle] ||= []
  rows_by_handle[handle] << row.to_h.transform_values { |v| v&.encode('UTF-8', invalid: :replace, undef: :replace) }
end
puts "  #{rows_by_handle.size} products in CSV"

fixed    = 0
skipped  = 0
total    = 0

rows_by_handle.each do |handle, rows|
  # Find product by slug (matches import logic)
  slug = handle.sub(/-\d{4}$/, '')
  product = Spree::Product.find_by(slug: slug) ||
            Spree::Product.find_by(slug: "#{slug}-ion")
  next unless product

  total += 1

  # Count current valid images (local service only)
  current_images = product.master.images.joins(attachment_attachment: :blob)
    .where(active_storage_blobs: { service_name: 'local' }).count
  variant_images = Spree::Variant.where(product: product, is_master: false)
    .joins(:images => { attachment_attachment: :blob })
    .where(active_storage_blobs: { service_name: 'local' }).count

  # Collect expected images from CSV
  expected_product_imgs = rows.map { |r| r['Image Src'] }.compact.uniq.reject(&:empty?)
  expected_variant_imgs = rows.map { |r| r['Variant Image'] }.compact.uniq.reject(&:empty?)

  if current_images >= expected_product_imgs.size && variant_images >= expected_variant_imgs.size
    skipped += 1
    next
  end

  print "\n  [#{total}] #{product.name} (has #{current_images}/#{expected_product_imgs.size} product imgs, #{variant_images}/#{expected_variant_imgs.size} variant imgs)"

  attached_images = {}

  rows.each do |row|
    sku         = row['Variant SKU']
    image_src   = row['Image Src']
    variant_img = row['Variant Image']
    opt1_val    = row['Option1 Value']
    opt2_val    = row['Option2 Value']

    # Product-level image
    if image_src.present? && !attached_images[image_src]
      ok = attach_image(product.master, image_src)
      attached_images[image_src] = true if ok
      print ok ? " p✓" : " p✗"
    end

    # Variant-level image
    if variant_img.present? && !attached_images[variant_img] && sku.present?
      variant = Spree::Variant.find_by(sku: sku)
      if variant
        ok = attach_image(variant, variant_img)
        attached_images[variant_img] = true if ok
        print ok ? " v✓" : " v✗"
      end
    end
  end

  fixed += 1
end

puts "\n\n#{'='*50}"
puts "Total ION products in DB: #{total}"
puts "Fixed (re-downloaded images): #{fixed}"
puts "Skipped (images already ok): #{skipped}"
puts "\nCloudflare blobs remaining: #{ActiveStorage::Blob.where(service_name: 'cloudflare').count}"
