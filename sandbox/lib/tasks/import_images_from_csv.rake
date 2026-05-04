require "open-uri"
require "csv"

namespace :images do
  desc "Import missing product images from CSV spreadsheet by matching variant barcodes"
  task import_from_csv: :environment do
    csv_path = ENV["CSV_PATH"] || Rails.root.join("tmp", "products_sheet.csv")

    unless File.exist?(csv_path)
      puts "❌ CSV file not found at #{csv_path}"
      puts "   Download it first:  curl -sL 'https://docs.google.com/spreadsheets/d/1I0HNNCyuTl1PJFV-3n5kn6Fz6Bk-02BFz7nlB4hjIHg/export?format=csv' -o #{csv_path}"
      exit 1
    end

    puts "=== Loading CSV ==="
    # Build a lookup: barcode → { image_url, variant_image_url, title }
    # In Shopify CSV, a product's first row has the Image Src (product-level image).
    # Subsequent variant rows have Variant Image (variant-specific image).
    # We want to use Variant Image if available, otherwise fall back to Image Src.
    barcode_to_image = {}
    current_product_image = nil

    CSV.foreach(csv_path, headers: true, liberal_parsing: true) do |row|
      barcode = row["Variant Barcode"].to_s.strip
      image_src = row["Image Src"].to_s.strip
      variant_image = row["Variant Image"].to_s.strip
      title = row["Title"].to_s.strip

      # Track product-level image (only set on first row of each product)
      current_product_image = image_src if image_src.present?

      next if barcode.blank?

      # Prefer variant image, fall back to product image
      best_image = variant_image.presence || current_product_image
      next if best_image.blank?

      barcode_to_image[barcode] = {
        image_url: best_image,
        title: title
      }
    end

    puts "  CSV barcodes with images: #{barcode_to_image.size}"

    # Build lookup of Spree variants by barcode (EAN)
    # Spree stores barcodes in Spree::Variant#barcode
    puts "\n=== Loading Spree variants ==="
    variants_by_barcode = {}
    Spree::Variant.where.not(barcode: [nil, ""]).includes(:product, :images).find_each do |variant|
      bc = variant.barcode.to_s.strip
      variants_by_barcode[bc] = variant if bc.present?
    end
    puts "  Spree variants with barcodes: #{variants_by_barcode.size}"

    # Find matches: variants whose product (or the variant itself) has NO images
    puts "\n=== Finding products missing images ==="
    matched = 0
    skipped_has_image = 0
    no_match = 0
    errors = 0
    downloaded = 0

    # Group by product to avoid attaching multiple images to the same product
    products_processed = Set.new

    barcode_to_image.each do |barcode, data|
      variant = variants_by_barcode[barcode]
      unless variant
        no_match += 1
        next
      end

      product = variant.product
      next unless product

      # Check if the product's master already has a working image
      # (not the "Untitled design.png" placeholder)
      master_images = product.master.images.includes(attachment_attachment: :blob)
      has_real_image = master_images.any? do |img|
        blob = img.attachment&.blob rescue nil
        next false unless blob
        fname = blob.filename.to_s
        # Skip placeholder images
        fname != "Untitled design.png" && fname != "placeholder.png"
      end

      if has_real_image
        skipped_has_image += 1
        next
      end

      # Don't process the same product twice
      next if products_processed.include?(product.id)
      products_processed.add(product.id)

      matched += 1
      image_url = data[:image_url]

      begin
        puts "  📥 #{product.name} (barcode: #{barcode})"
        puts "     URL: #{image_url[0..80]}..."

        # Download image
        uri = URI.parse(image_url)
        image_data = URI.open(image_url, read_timeout: 30).read

        # Determine content type and filename
        extension = File.extname(URI.parse(image_url).path).downcase
        extension = ".jpg" if extension.blank?
        content_type = case extension
                       when ".png" then "image/png"
                       when ".webp" then "image/webp"
                       when ".gif" then "image/gif"
                       else "image/jpeg"
                       end

        filename = File.basename(URI.parse(image_url).path)
        filename = "#{product.slug}#{extension}" if filename.blank?

        # Attach to the master variant
        image = product.master.images.new(
          alt: product.name,
          position: 1
        )
        image.attachment.attach(
          io: StringIO.new(image_data),
          filename: filename,
          content_type: content_type
        )
        image.save!
        downloaded += 1
        puts "     ✅ Attached successfully"

      rescue => e
        errors += 1
        puts "     ❌ Error: #{e.message}"
      end
    end

    puts "\n=== Summary ==="
    puts "CSV barcodes:           #{barcode_to_image.size}"
    puts "Matched to Spree:       #{matched + skipped_has_image}"
    puts "  Already has image:    #{skipped_has_image}"
    puts "  Missing image:        #{matched}"
    puts "  Downloaded & attached:#{downloaded}"
    puts "  Errors:               #{errors}"
    puts "No match in Spree:      #{no_match}"
    puts "Products processed:     #{products_processed.size}"
  end

  desc "DRY RUN: Show which products would get images from CSV (no changes made)"
  task preview_csv_import: :environment do
    csv_path = ENV["CSV_PATH"] || Rails.root.join("tmp", "products_sheet.csv")

    unless File.exist?(csv_path)
      puts "❌ CSV file not found at #{csv_path}"
      exit 1
    end

    # Build CSV lookup
    barcode_to_image = {}
    current_product_image = nil

    CSV.foreach(csv_path, headers: true, liberal_parsing: true) do |row|
      barcode = row["Variant Barcode"].to_s.strip
      image_src = row["Image Src"].to_s.strip
      variant_image = row["Variant Image"].to_s.strip

      current_product_image = image_src if image_src.present?
      next if barcode.blank?

      best_image = variant_image.presence || current_product_image
      next if best_image.blank?

      barcode_to_image[barcode] = { image_url: best_image, title: row["Title"].to_s.strip }
    end

    # Build Spree variant lookup
    variants_by_barcode = {}
    Spree::Variant.where.not(barcode: [nil, ""]).includes(:product, :images).find_each do |v|
      bc = v.barcode.to_s.strip
      variants_by_barcode[bc] = v if bc.present?
    end

    # Report
    would_import = 0
    already_ok = 0
    no_match = 0
    products_seen = Set.new

    barcode_to_image.each do |barcode, data|
      variant = variants_by_barcode[barcode]
      unless variant
        no_match += 1
        next
      end

      product = variant.product
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
        puts "  🔄 #{product.name} (barcode: #{barcode}) ← #{data[:image_url][0..60]}..."
      end
    end

    puts "\n=== DRY RUN Summary ==="
    puts "Would import images for: #{would_import} products"
    puts "Already have images:     #{already_ok} products"
    puts "No barcode match:        #{no_match} rows"
  end
end
