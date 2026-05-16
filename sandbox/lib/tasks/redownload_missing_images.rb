require 'open-uri'
require 'csv'
require 'set'
require 'fileutils'

puts "=== Re-download Missing Images from CSV CDN URLs ==="
puts "Time: #{Time.current}"
puts ""

# ── Storage root (DiskService) ─────────────────────────────────────────────────
storage_root = Rails.root.join('storage').to_s
puts "Storage root: #{storage_root}"

def blob_file_path(storage_root, key)
  # Rails DiskService stores files at: storage/XX/YY/key
  # where XX = first 2 chars, YY = chars 3-4 of key
  dir1 = key[0, 2]
  dir2 = key[2, 2]
  File.join(storage_root, dir1, dir2, key)
end

def blob_exists?(storage_root, key)
  File.exist?(blob_file_path(storage_root, key))
end

# ── 1. Load CSV → EAN → image_url map ─────────────────────────────────────────
csv_path = Rails.root.join('tmp', 'products_sheet.csv')
puts "Loading CSV: #{csv_path}"
puts "CSV exists: #{File.exist?(csv_path)}"

ean_to_url = {}
current_product_url = nil

CSV.foreach(csv_path, headers: true, liberal_parsing: true) do |row|
  ean         = row['Variant Barcode'].to_s.strip
  image_src   = row['Image Src'].to_s.strip
  variant_img = row['Variant Image'].to_s.strip

  current_product_url = image_src if image_src.present?
  next if ean.blank?

  best_url = variant_img.presence || current_product_url
  ean_to_url[ean] = best_url if best_url.present?
end

puts "CSV EAN→URL pairs: #{ean_to_url.size}"
puts ""

# ── 2. Build EAN → Spree::Variant lookup ──────────────────────────────────────
puts "Loading Spree variants with EAN..."
variant_by_ean = {}
Spree::Variant.where.not(barcode: [nil, '']).find_each do |v|
  ean = v.barcode.to_s.strip
  variant_by_ean[ean] ||= v
end
puts "Variants with EAN: #{variant_by_ean.size}"
puts ""

# ── 3. Process each EAN from CSV ──────────────────────────────────────────────
puts "=== Starting re-download ==="

restored   = 0
skipped    = 0
failed     = 0
no_match   = 0
processed  = 0

ean_to_url.each do |ean, cdn_url|
  processed += 1
  print "\r[#{processed}/#{ean_to_url.size}] Restored: #{restored} | Failed: #{failed} | NoMatch: #{no_match}" if processed % 10 == 0

  variant = variant_by_ean[ean]
  unless variant
    no_match += 1
    next
  end

  # Get all asset blobs for this variant AND its product master
  record_ids = [variant.id, variant.product&.master&.id].compact.uniq

  blobs = ActiveStorage::Blob
    .joins("INNER JOIN active_storage_attachments ON active_storage_attachments.blob_id = active_storage_blobs.id")
    .where("active_storage_attachments.record_type = 'Spree::Asset'")
    .where("active_storage_attachments.record_id IN (?)", record_ids)
    .select("DISTINCT active_storage_blobs.*")

  blobs.each do |blob|
    # Check if file exists on disk
    if blob_exists?(storage_root, blob.key)
      skipped += 1
      next
    end

    # File is missing — re-download from CDN
    target_path = blob_file_path(storage_root, blob.key)
    FileUtils.mkdir_p(File.dirname(target_path))

    begin
      response = URI.open(
        cdn_url,
        "User-Agent" => "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36",
        read_timeout: 30,
        open_timeout: 10
      )

      File.binwrite(target_path, response.read)
      restored += 1
      STDOUT.print "✓"
      STDOUT.flush
    rescue OpenURI::HTTPError => e
      failed += 1
      STDOUT.print "✗"
      STDOUT.flush
    rescue => e
      failed += 1
      STDOUT.print "!"
      STDOUT.flush
    end
  end
end

puts "\n\n=== DONE ==="
puts "Processed EANs: #{processed}"
puts "Restored:       #{restored}"
puts "Already exists: #{skipped}"
puts "Failed:         #{failed}"
puts "No EAN match:   #{no_match}"
puts ""
puts "Finished: #{Time.current}"
