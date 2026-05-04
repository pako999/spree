require "csv"
require "net/http"

namespace :images do
  desc "Import variant-specific images from ION CSV by matching Variant Barcode to Variant Image column"
  task import_variant_images: :environment do
    csv_path = ENV["CSV_PATH"] || Rails.root.join("tmp", "products_sheet.csv")

    unless File.exist?(csv_path)
      puts "❌ CSV file not found at #{csv_path}"
      exit 1
    end

    puts "=== Loading CSV ==="
    # Build lookup: barcode → variant_image_url
    # Each row has a barcode and a variant-specific image URL
    variant_images = []

    CSV.foreach(csv_path, headers: true, liberal_parsing: true) do |row|
      barcode = row["Variant Barcode"].to_s.strip
      variant_image = row["Variant Image"].to_s.strip

      next if barcode.blank? || variant_image.blank?
      next unless variant_image.start_with?("http")

      variant_images << {
        barcode: barcode,
        image_url: variant_image,
        title: row["Title"].to_s.strip
      }
    end

    puts "  CSV rows with barcode + variant image: #{variant_images.size}"

    # Build Spree variant lookup by barcode
    puts "\n=== Loading Spree variants ==="
    variants_by_barcode = {}
    Spree::Variant.where(is_master: false).find_each do |variant|
      bc = variant.barcode.to_s.strip
      variants_by_barcode[bc] = variant if bc.present?
    end
    puts "  Non-master variants with barcodes: #{variants_by_barcode.size}"

    # Import
    puts "\n=== Importing variant images ==="
    matched = 0
    skipped_has_image = 0
    no_match = 0
    downloaded = 0
    errors = 0

    variant_images.each do |data|
      variant = variants_by_barcode[data[:barcode]]
      unless variant
        no_match += 1
        next
      end

      # Check if this variant already has its own image
      existing_images = variant.images.includes(attachment_attachment: :blob)
      has_own_image = existing_images.any? do |img|
        begin
          blob = img.attachment&.blob
          next false unless blob
          blob.filename.to_s != "Untitled design.png"
        rescue
          false
        end
      end

      if has_own_image
        skipped_has_image += 1
        next
      end

      matched += 1

      begin
        uri = URI.parse(data[:image_url])
        fname = File.basename(uri.path)
        puts "  📥 #{variant.product&.name} [#{variant.options_text}] barcode=#{data[:barcode]} → #{fname}"

        response = Net::HTTP.get_response(uri)
        unless response.is_a?(Net::HTTPSuccess)
          errors += 1
          puts "     ❌ HTTP #{response.code}"
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

        filename = fname.presence || "#{variant.sku || data[:barcode]}#{extension}"

        image = variant.images.new(
          alt: "#{variant.product&.name} #{variant.options_text}".strip,
          position: 1
        )
        image.attachment.attach(
          io: StringIO.new(image_data),
          filename: filename,
          content_type: content_type
        )
        image.save!
        downloaded += 1
        puts "     ✅ OK"

      rescue => e
        errors += 1
        puts "     ❌ #{e.message}"
      end
    end

    puts "\n=== Summary ==="
    puts "CSV variant rows:          #{variant_images.size}"
    puts "Matched to Spree variants: #{matched + skipped_has_image}"
    puts "  Already has image:       #{skipped_has_image}"
    puts "  Missing → downloaded:    #{downloaded}"
    puts "  Errors:                  #{errors}"
    puts "No match in Spree:         #{no_match}"
  end

  desc "DRY RUN: Preview variant image imports from ION CSV"
  task preview_variant_images: :environment do
    csv_path = ENV["CSV_PATH"] || Rails.root.join("tmp", "products_sheet.csv")

    unless File.exist?(csv_path)
      puts "❌ CSV file not found at #{csv_path}"
      exit 1
    end

    variant_images = []
    CSV.foreach(csv_path, headers: true, liberal_parsing: true) do |row|
      barcode = row["Variant Barcode"].to_s.strip
      variant_image = row["Variant Image"].to_s.strip
      next if barcode.blank? || variant_image.blank?
      next unless variant_image.start_with?("http")
      variant_images << { barcode: barcode, image_url: variant_image, title: row["Title"].to_s.strip }
    end

    variants_by_barcode = {}
    Spree::Variant.where(is_master: false).find_each do |v|
      bc = v.barcode.to_s.strip
      variants_by_barcode[bc] = v if bc.present?
    end

    would_import = 0
    already_ok = 0
    no_match = 0

    variant_images.each do |data|
      variant = variants_by_barcode[data[:barcode]]
      unless variant
        no_match += 1
        next
      end

      has_own_image = variant.images.includes(attachment_attachment: :blob).any? do |img|
        begin
          blob = img.attachment&.blob
          blob && blob.filename.to_s != "Untitled design.png"
        rescue
          false
        end
      end

      if has_own_image
        already_ok += 1
      else
        would_import += 1
        puts "  🔄 #{variant.product&.name} [#{variant.options_text}] barcode=#{data[:barcode]}" if would_import <= 30
      end
    end

    puts "\n=== DRY RUN Summary ==="
    puts "Would import: #{would_import} variant images"
    puts "Already have: #{already_ok}"
    puts "No match:     #{no_match}"
  end
end
