namespace :spree do
  desc 'Set up sport category taxons with images for the homepage SportCategoryGrid section'
  task setup_sport_categories: :environment do
    store = Spree::Store.default

    taxonomy = Spree::Taxonomy.find_or_create_by!(name: 'Sport Categories', store: store)
    root = taxonomy.root

    categories = [
      { name: 'Kiteboarding', slug: 'kiteboarding',         image: 'kiteboarding.jpg',  position: 1 },
      { name: 'Windsurfing',  slug: 'windsurfing',          image: 'windsurfing.jpg',   position: 2 },
      { name: 'Wingfoil',     slug: 'wingfoil',             image: 'wingfoil.jpg',      position: 3 },
      { name: 'SUP',          slug: 'sup',                  image: 'sup.jpg',           position: 4 },
      { name: 'Wetsuits',     slug: 'wetsuits',             image: 'wetsuits.jpg',      position: 5 },
      { name: 'ION Bike',     slug: 'ion-bike',             image: 'ion-bike.jpg',      position: 6 }
    ]

    images_dir = Rails.root.join('public', 'images', 'categories')

    categories.each do |cat|
      taxon = Spree::Taxon.find_or_initialize_by(permalink: "sport-categories/#{cat[:slug]}", taxonomy: taxonomy)
      taxon.name     = cat[:name]
      taxon.parent   = root
      taxon.position = cat[:position]
      taxon.save!

      image_path = images_dir.join(cat[:image])

      if image_path.exist?
        if taxon.page_builder_image.attached?
          puts "  Skipping image for #{cat[:name]} (already attached)"
        else
          taxon.page_builder_image.attach(
            io:           File.open(image_path),
            filename:     cat[:image],
            content_type: 'image/jpeg'
          )
          puts "  ✓ Attached image for #{cat[:name]}"
        end
      else
        puts "  ⚠ Image not found: #{image_path} — upload manually via admin"
      end

      puts "✓ #{cat[:name]} (#{taxon.permalink})"
    end

    puts "\nDone! Add a SportCategoryGrid section to your homepage page via the admin page builder"
    puts "and link to these taxons: #{categories.map { |c| c[:name] }.join(', ')}"
  end
end
