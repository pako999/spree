require 'open-uri'
require 'net/http'
require 'digest'

namespace :images do
  desc "Restore missing product images by re-downloading from CDN source"
  task restore_missing: :environment do
    puts "=== Restoring Missing Product Images ==="
    puts "Storage service: #{Rails.application.config.active_storage.service}"
    puts ""

    # CDN base URLs to try in order
    CDN_BASES = [
      "https://cdn.boards-and-more.com/system/product_picture_gallery_pictures/files",
      "https://boards-and-more.com/system/product_picture_gallery_pictures/files",
    ].freeze

    # Get all Spree::Asset blobs
    missing_blobs = ActiveStorage::Blob
      .joins("INNER JOIN active_storage_attachments ON active_storage_attachments.blob_id = active_storage_blobs.id")
      .where("active_storage_attachments.record_type = 'Spree::Asset'")
      .select("active_storage_blobs.*")
      .distinct

    total = missing_blobs.count
    puts "Total asset blobs in DB: #{total}"

    restored   = 0
    skipped    = 0
    failed     = 0
    not_cdn    = 0

    missing_blobs.find_each.with_index do |blob, idx|
      print "\r[#{idx+1}/#{total}] Restored: #{restored} | Skipped: #{skipped} | Failed: #{failed}"

      # Check if already in storage
      begin
        next skipped += 1 if blob.service.exist?(blob.key)
      rescue => e
        # service.exist? might raise on some backends
      end

      filename = blob.filename.to_s
      
      # Only try to fetch ION/boards-and-more style filenames (numeric prefix pattern)
      unless filename.match?(/\A\d{5}-\d{4}/) || filename.match?(/\A\d{5}-\d{3}/)
        not_cdn += 1
        next
      end

      # Try to find the image on the CDN
      # boards-and-more CDN pattern: the files are stored by numeric ID prefix
      # Example: 48230-4333_IOW-Boots_...
      # We try multiple CDN URL patterns
      downloaded = false
      
      # Extract the numeric ID from the filename (first part before underscore)
      file_id = filename.split('_').first  # e.g. "48230-4333"
      
      cdn_urls_to_try = [
        # Direct boards-and-more CDN with various folder structures
        "https://cdn.boards-and-more.com/system/product_picture_gallery_pictures/files/#{filename}",
        "https://cdn.boards-and-more.com/media/catalog/product/#{filename}",
      ]

      cdn_urls_to_try.each do |url|
        begin
          response = URI.open(url,
            "User-Agent" => "Mozilla/5.0 (compatible; Googlebot/2.1)",
            read_timeout: 30,
            open_timeout: 10
          )
          
          blob.upload(response, identify: false)
          restored += 1
          downloaded = true
          break
        rescue OpenURI::HTTPError, Net::OpenTimeout, Net::ReadTimeout, SocketError, Errno::ECONNREFUSED => e
          next  # Try next URL
        rescue => e
          next
        end
      end

      failed += 1 unless downloaded
    end

    puts "\n\n=== Done ==="
    puts "Restored:       #{restored}"
    puts "Already exists: #{skipped}"
    puts "Not CDN images: #{not_cdn}"
    puts "Failed:         #{failed}"
  end

  desc "Show stats on missing images without downloading"
  task missing_stats: :environment do
    puts "=== Missing Image Stats ==="
    
    all_asset_blobs = ActiveStorage::Blob
      .joins("INNER JOIN active_storage_attachments ON active_storage_attachments.blob_id = active_storage_blobs.id")
      .where("active_storage_attachments.record_type = 'Spree::Asset'")
      .select("DISTINCT active_storage_blobs.*")

    total = all_asset_blobs.count
    puts "Total asset blobs: #{total}"
    
    missing = 0
    existing = 0
    cdn_pattern = 0
    other = 0

    all_asset_blobs.find_each do |blob|
      begin
        if blob.service.exist?(blob.key)
          existing += 1
        else
          missing += 1
          if blob.filename.to_s.match?(/\A\d{5}/)
            cdn_pattern += 1
          else
            other += 1
          end
        end
      rescue => e
        missing += 1
      end
    end

    puts "Existing in storage: #{existing}"
    puts "Missing:             #{missing}"
    puts "  - CDN pattern:     #{cdn_pattern}"
    puts "  - Other filenames: #{other}"
  end

  desc "Purge orphaned ActiveStorage::VariantRecord rows for missing blobs"
  task purge_orphaned_variants: :environment do
    puts "=== Purging orphaned variant records ==="
    count = 0
    ActiveStorage::VariantRecord.find_each do |vr|
      begin
        vr.destroy unless vr.blob.service.exist?(vr.blob.key)
        count += 1
      rescue
        next
      end
    end
    puts "Purged #{count} orphaned variant records"
  end
end
