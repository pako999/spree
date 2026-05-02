namespace :maintenance do
  desc "Update product meta titles: replace 'surfworld' with 'surf-store.com'"
  task update_meta_titles: :environment do
    count = 0
    updated_count = 0

    # Get all supported locales to handle translations
    locales = Spree::Store.all.flat_map(&:supported_locales_list).uniq
    locales = [I18n.default_locale] if locales.empty?

    puts "Checking products for 'surfworld' in meta titles across locales: #{locales.join(', ')}..."

    Spree::Product.find_each do |product|
      locales.each do |locale|
        Mobility.with_locale(locale) do
          if product.meta_title&.downcase&.include?('surfworld')
            old_title = product.meta_title
            # Use regex for case-insensitive replacement
            new_title = old_title.gsub(/surfworld/i, 'surf-store.com')
            
            if old_title != new_title
              product.update_column(:meta_title, new_title) if !Spree.use_translations?
              # For Mobility, we might need to update the translation record directly if update_column doesn't work with Mobility
              # but usually product.meta_title = new_title; product.save works.
              # However, for speed and safety in a maintenance task:
              product.meta_title = new_title
              if product.save(validate: false)
                updated_count += 1
                puts "[#{locale}] Updated: '#{old_title}' -> '#{new_title}'"
              end
            end
          end
        end
      end
    end

    puts "Done. Total updates: #{updated_count}"
  end
  desc "Assign product primary image to all variants missing images"
  task assign_variant_images: :environment do
    updated = 0
    skipped = 0
    no_image = 0

    puts "Finding variants without images..."

    Spree::Product.includes(:variants, :images).find_each do |product|
      # Get the product's primary image (first image)
      primary_image = product.images.first
      unless primary_image
        no_image += 1
        next
      end

      product.variants.each do |variant|
        if variant.images.any?
          skipped += 1
          next
        end

        # Duplicate the primary image's blob for the variant
        begin
          original_blob = primary_image.attachment.blob
          new_image = variant.images.build(
            alt: primary_image.alt || product.name,
            position: 1
          )
          new_image.attachment.attach(
            io: StringIO.new(original_blob.download),
            filename: original_blob.filename.to_s,
            content_type: original_blob.content_type
          )
          new_image.save!
          updated += 1
          puts "  ✅ #{product.name} / variant #{variant.options_text} — image assigned"
        rescue => e
          puts "  ❌ #{product.name} / variant #{variant.options_text} — #{e.message}"
        end
      end
    end

    puts "\nDone! Assigned: #{updated}, Skipped (already had image): #{skipped}, Products without images: #{no_image}"
  end
end
