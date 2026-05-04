require "open-uri"
require "csv"

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
    # Build lookup: group rows by MasterItem (product group)
    # Each master group shares the same images (first row often has ImageURLpng0 = main gallery)
    # We want ALL image URLs for each product group
    product_groups = {} # master_item => { image_urls: [], gtins: [], skus: [], name: '' }

    CSV.foreach(csv_path, headers: true, liberal_parsing: true) do |row|
      gtin = row["GTIN"].to_s.strip
      sku = row["Artikelnummer"].to_s.strip
      item_code = row["ItemCode"].to_s.strip
      master_item = row["MasterItem"].to_s.strip
      master_name = row["Master_ItemName"].to_s.strip
      item_name = row["ItemName"].to_s.strip

      # Use master_item to group, fall back to item_code
      group_key = master_item.presence || item_code
      next if group_key.blank?

      product_groups[group_key] ||= {
        image_urls: [],
        gtins: [],
        skus: [],
        name: master_name.presence || item_name
      }

      # Collect unique image URLs from all columns
      image_columns.each do |col|
        url = row[col].to_s.strip
        if url.present? && url.start_with?("http") && !product_groups[group_key][:image_urls].include?(url)
          product_groups[group_key][:image_urls] << url
        end
      end

      # Collect barcodes and SKUs for matching
      product_groups[group_key][:gtins] << gtin if gtin.present?
      product_groups[group_key][:skus] << sku if sku.present?
    end

    # Deduplicate
    product_groups.each_value do |pg|
      pg[:gtins].uniq!
      pg[:skus].uniq!
      pg[:image_urls].uniq!
    end

    total_groups = product_groups.size
    groups_with_images = product_groups.count { |_, pg| pg[:image_urls].any? }
    puts "  Product groups: #{total_groups}"
    puts "  Groups with images: #{groups_with_images}"

    # Build Spree variant lookups
    puts "\n=== Loading Spree variants ==="
    variants_by_barcode = {}
    variants_by_sku = {}
    Spree::Variant.where.not(deleted_at: nil).or(Spree::Variant.where(deleted_at: nil))
                  .includes(:product, :images)
                  .find_each do |variant|
      bc = variant.barcode.to_s.strip
      variants_by_barcode[bc] = variant if bc.present?
      sk = variant.sku.to_s.strip
      variants_by_sku[sk] = variant if sk.present?
    end
    puts "  Variants by barcode: #{variants_by_barcode.size}"
    puts "  Variants by SKU: #{variants_by_sku.size}"

    # Match and import
    puts "\n=== Importing missing images ==="
    matched_products = 0
    skipped_has_image = 0
    no_match = 0
    total_downloaded = 0
    errors = 0
    products_processed = Set.new

    product_groups.each do |group_key, pg|
      next if pg[:image_urls].empty?

      # Find matching Spree product via GTIN or SKU
      matched_variant = nil

      # Try GTIN first
      pg[:gtins].each do |gtin|
        matched_variant = variants_by_barcode[gtin]
        break if matched_variant
      end

      # Fall back to SKU
      unless matched_variant
        pg[:skus].each do |sku|
          matched_variant = variants_by_sku[sku]
          break if matched_variant
        end
      end

      unless matched_variant
        no_match += 1
        next
      end

      product = matched_variant.product
      next unless product
      next if products_processed.include?(product.id)
      products_processed.add(product.id)

      # Check if product already has real images
      master_images = product.master.images.includes(attachment_attachment: :blob)
      has_real_image = master_images.any? do |img|
        blob = img.attachment&.blob rescue nil
        next false unless blob
        fname = blob.filename.to_s
        fname != "Untitled design.png" && fname != "placeholder.png"
      end

      if has_real_image
        skipped_has_image += 1
        next
      end

      matched_products += 1
      puts "\n  📦 #{product.name} (#{pg[:name]})"

      # Download and attach each image
      pg[:image_urls].each_with_index do |image_url, idx|
        begin
          puts "    📥 [#{idx + 1}/#{pg[:image_urls].size}] #{image_url[0..80]}..."

          image_data = URI.open(image_url, read_timeout: 30).read

          extension = File.extname(URI.parse(image_url).path).downcase
          extension = ".png" if extension.blank?
          content_type = case extension
                         when ".jpg", ".jpeg" then "image/jpeg"
                         when ".webp" then "image/webp"
                         when ".gif" then "image/gif"
                         else "image/png"
                         end

          filename = File.basename(URI.parse(image_url).path)
          filename = "#{product.slug}-#{idx}#{extension}" if filename.blank?

          image = product.master.images.new(
            alt: product.name,
            position: idx + 1
          )
          image.attachment.attach(
            io: StringIO.new(image_data),
            filename: filename,
            content_type: content_type
          )
          image.save!
          total_downloaded += 1
          puts "       ✅ Attached (position #{idx + 1})"

        rescue => e
          errors += 1
          puts "       ❌ Error: #{e.message}"
        end
      end
    end

    puts "\n=== Summary ==="
    puts "Product groups in CSV:    #{total_groups}"
    puts "Matched to Spree:         #{matched_products + skipped_has_image}"
    puts "  Already has images:     #{skipped_has_image}"
    puts "  Missing → imported:     #{matched_products}"
    puts "  Total images downloaded:#{total_downloaded}"
    puts "  Errors:                 #{errors}"
    puts "No match in Spree:        #{no_match}"
    puts "Products processed:       #{products_processed.size}"
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
    Spree::Variant.includes(:product, :images).find_each do |v|
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

      master_images = product.master.images.includes(attachment_attachment: :blob)
      has_real_image = master_images.any? do |img|
        blob = img.attachment&.blob rescue nil
        next false unless blob
        blob.filename.to_s != "Untitled design.png"
      end

      if has_real_image
        already_ok += 1
      else
        would_import += 1
        total_images += pg[:image_urls].size
        puts "  🔄 #{product.name} ← #{pg[:image_urls].size} images (GTIN: #{pg[:gtins].first || 'none'}, SKU: #{pg[:skus].first || 'none'})"
      end
    end

    puts "\n=== DRY RUN Summary ==="
    puts "Would import for: #{would_import} products (#{total_images} total images)"
    puts "Already have images: #{already_ok} products"
    puts "No match in Spree: #{no_match} groups"
  end
end
