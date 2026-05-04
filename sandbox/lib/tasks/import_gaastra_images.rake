require "open-uri"
require "csv"
require "net/http"

namespace :images do
  desc "Import missing product images from Gaastra CSV by matching GTIN (barcode) or SKU"
  task import_gaastra: :environment do
    csv_path = ENV["CSV_PATH"] || Rails.root.join("tmp", "gaastra_sheet.csv")

    unless File.exist?(csv_path)
      puts "❌ CSV file not found at #{csv_path}"
      puts "   Download it first:  curl -sL 'https://docs.google.com/spreadsheets/d/1WQpNTIi5xcZi4pmjZoaokliFEmwxiKLCJvLdSXp3bC4/export?format=csv' -o #{csv_path}"
      exit 1
    end

    image_columns = %w[ImageURLpng0 ImageURLpng1 ImageURLpng2 ImageURLpng3 ImageURLpng4 ImageURLpng5 ImageURLpng6]

    puts "=== Loading Gaastra CSV ==="
    product_groups = {}

    CSV.foreach(csv_path, headers: true, liberal_parsing: true) do |row|
      gtin = row["GTIN"].to_s.strip
      sku = row["Artikelnummer"].to_s.strip
      item_code = row["ItemCode"].to_s.strip
      master_item = row["MasterItem"].to_s.strip
      master_name = row["Master_ItemName"].to_s.strip
      item_name = row["ItemName"].to_s.strip

      group_key = master_item.presence || item_code
      next if group_key.blank?

      product_groups[group_key] ||= {
        image_urls: [],
        gtins: [],
        skus: [],
        name: master_name.presence || item_name
      }

      image_columns.each do |col|
        url = row[col].to_s.strip
        if url.present? && url.start_with?("http") && !product_groups[group_key][:image_urls].include?(url)
          product_groups[group_key][:image_urls] << url
        end
      end

      product_groups[group_key][:gtins] << gtin if gtin.present?
      product_groups[group_key][:skus] << sku if sku.present?
    end

    product_groups.each_value do |pg|
      pg[:gtins].uniq!
      pg[:skus].uniq!
      pg[:image_urls].uniq!
    end

    puts "  Product groups: #{product_groups.size}"

    # Build Spree variant lookups
    puts "\n=== Loading Spree variants ==="
    variants_by_barcode = {}
    variants_by_sku = {}
    Spree::Variant.find_each do |variant|
      bc = variant.barcode.to_s.strip
      variants_by_barcode[bc] = variant if bc.present?
      sk = variant.sku.to_s.strip
      variants_by_sku[sk] = variant if sk.present?
    end
    puts "  Variants by barcode: #{variants_by_barcode.size}"
    puts "  Variants by SKU: #{variants_by_sku.size}"

    # Match and import
    puts "\n=== Importing images ==="
    matched_products = 0
    skipped_complete = 0
    no_match = 0
    total_downloaded = 0
    total_skipped_existing = 0
    errors = 0
    products_processed = Set.new

    product_groups.each do |group_key, pg|
      next if pg[:image_urls].empty?

      matched_variant = nil
      pg[:gtins].each { |g| matched_variant ||= variants_by_barcode[g] }
      pg[:skus].each { |s| matched_variant ||= variants_by_sku[s] } unless matched_variant

      unless matched_variant
        no_match += 1
        next
      end

      product = matched_variant.product
      next unless product
      next if products_processed.include?(product.id)
      products_processed.add(product.id)

      # Get existing image filenames to skip duplicates
      existing_filenames = Set.new
      product.master.images.includes(attachment_attachment: :blob).each do |img|
        begin
          blob = img.attachment&.blob
          existing_filenames.add(blob.filename.to_s) if blob
        rescue
          next
        end
      end

      # Filter to only URLs whose filename is not already attached
      urls_to_download = pg[:image_urls].select do |url|
        begin
          fname = File.basename(URI.parse(url).path)
          fname && !existing_filenames.include?(fname)
        rescue
          false
        end
      end

      if urls_to_download.empty?
        skipped_complete += 1
        next
      end

      matched_products += 1
      current_position = product.master.images.maximum(:position).to_i

      puts "\n  📦 #{product.name} (#{urls_to_download.size} new images, #{existing_filenames.size} existing)"

      urls_to_download.each_with_index do |image_url, idx|
        current_position += 1
        attempts = 0
        response = nil
        uri = URI.parse(image_url)

        puts "    📥 [#{idx + 1}/#{urls_to_download.size}] #{File.basename(uri.path)}"

        # Retry up to 3 times for 403s
        loop do
          attempts += 1
          response = Net::HTTP.get_response(uri)
          break unless response.code == "403" && attempts < 3
          sleep(attempts)
        end

        begin

          unless response.is_a?(Net::HTTPSuccess)
            errors += 1
            puts "       ❌ HTTP #{response.code}"
            next
          end

          image_data = response.body
          extension = File.extname(uri.path).downcase
          extension = ".png" if extension.blank?
          content_type = case extension
                         when ".jpg", ".jpeg" then "image/jpeg"
                         when ".webp" then "image/webp"
                         when ".gif" then "image/gif"
                         else "image/png"
                         end

          filename = File.basename(uri.path)
          filename = "#{product.slug}-#{idx}#{extension}" if filename.blank?

          image = product.master.images.new(
            alt: product.name,
            position: current_position
          )
          image.attachment.attach(
            io: StringIO.new(image_data),
            filename: filename,
            content_type: content_type
          )
          image.save!
          total_downloaded += 1
          puts "       ✅ OK"

        rescue => e
          errors += 1
          puts "       ❌ #{e.message}"
        end
      end
    end

    puts "\n=== Summary ==="
    puts "Product groups in CSV:     #{product_groups.size}"
    puts "Matched to Spree:          #{matched_products + skipped_complete}"
    puts "  Already complete:        #{skipped_complete}"
    puts "  Needed images:           #{matched_products}"
    puts "  Total images downloaded: #{total_downloaded}"
    puts "  Errors:                  #{errors}"
    puts "No match in Spree:         #{no_match}"
  end

  desc "DRY RUN: Preview Gaastra image imports"
  task preview_gaastra: :environment do
    csv_path = ENV["CSV_PATH"] || Rails.root.join("tmp", "gaastra_sheet.csv")

    unless File.exist?(csv_path)
      puts "❌ CSV file not found at #{csv_path}"
      exit 1
    end

    image_columns = %w[ImageURLpng0 ImageURLpng1 ImageURLpng2 ImageURLpng3 ImageURLpng4 ImageURLpng5 ImageURLpng6]

    product_groups = {}
    CSV.foreach(csv_path, headers: true, liberal_parsing: true) do |row|
      gtin = row["GTIN"].to_s.strip
      sku = row["Artikelnummer"].to_s.strip
      item_code = row["ItemCode"].to_s.strip
      master_item = row["MasterItem"].to_s.strip

      group_key = master_item.presence || item_code
      next if group_key.blank?

      product_groups[group_key] ||= {
        image_urls: [], gtins: [], skus: [],
        name: (row["Master_ItemName"].to_s.strip.presence || row["ItemName"].to_s.strip)
      }

      image_columns.each do |col|
        url = row[col].to_s.strip
        if url.present? && url.start_with?("http") && !product_groups[group_key][:image_urls].include?(url)
          product_groups[group_key][:image_urls] << url
        end
      end
      product_groups[group_key][:gtins] << gtin if gtin.present?
      product_groups[group_key][:skus] << sku if sku.present?
    end

    product_groups.each_value { |pg| pg[:gtins].uniq!; pg[:skus].uniq!; pg[:image_urls].uniq! }

    variants_by_barcode = {}
    variants_by_sku = {}
    Spree::Variant.find_each do |v|
      bc = v.barcode.to_s.strip
      variants_by_barcode[bc] = v if bc.present?
      sk = v.sku.to_s.strip
      variants_by_sku[sk] = v if sk.present?
    end

    would_import = 0
    already_ok = 0
    no_match = 0
    total_images = 0
    products_seen = Set.new

    product_groups.each do |_, pg|
      next if pg[:image_urls].empty?

      matched_variant = nil
      pg[:gtins].each { |g| matched_variant ||= variants_by_barcode[g] }
      pg[:skus].each { |s| matched_variant ||= variants_by_sku[s] } unless matched_variant

      unless matched_variant
        no_match += 1
        next
      end

      product = matched_variant.product
      next unless product
      next if products_seen.include?(product.id)
      products_seen.add(product.id)

      existing = Set.new
      product.master.images.includes(attachment_attachment: :blob).each do |img|
        begin
          blob = img.attachment&.blob
          existing.add(blob.filename.to_s) if blob
        rescue
          next
        end
      end

      new_urls = pg[:image_urls].select do |u|
        begin
          !existing.include?(File.basename(URI.parse(u).path))
        rescue
          false
        end
      end

      if new_urls.empty?
        already_ok += 1
      else
        would_import += 1
        total_images += new_urls.size
        puts "  🔄 #{product.name} ← #{new_urls.size} new images (#{existing.size} existing)"
      end
    end

    puts "\n=== DRY RUN Summary ==="
    puts "Would import for: #{would_import} products (#{total_images} total new images)"
    puts "Already complete: #{already_ok} products"
    puts "No match in Spree: #{no_match} groups"
  end
end
