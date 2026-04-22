# Attach hero images to SEO posts using relevant product images from the store
# Run: kamal app exec --reuse "bin/rails runner /rails/script/attach_post_hero_images.rb"

# Map post slugs to search terms for finding relevant product images
POST_IMAGE_MAP = {
  'best-kites-for-beginners-2026'    => 'Duotone Evo',
  'how-to-choose-a-wetsuit'          => 'ION Element',
  'windsurf-sail-size-guide'         => 'Duotone',
  'wing-foil-beginners-guide'        => 'Duotone Echo',
  'kiteboard-size-guide'             => 'Duotone Select',
  'best-harness-for-kitesurfing'     => 'ION Riot',
  'kitesurfing-tarifa-guide'         => 'Duotone',
  'kitesurfing-fuerteventura-guide'  => 'Cabrinha',
  'windsurfing-lake-garda-guide'     => 'Duotone',
  'kitesurfing-dakhla-morocco-guide' => 'Duotone',
  'wingfoil-spots-europe'            => 'Duotone Echo',
  'windsurfing-el-gouna-egypt'       => 'NeilPryde',
  'duotone-evo-vs-rebel'             => 'Duotone Evo',
  'best-windsurf-sails-2026'         => 'Gaastra',
  'cabrinha-switchblade-vs-duotone-evo' => 'Cabrinha Switchblade',
  'best-wetsuits-for-kitesurfing-2026' => 'ION Seek',
  'best-kite-for-intermediate-riders'  => 'Duotone Evo',
  'beginner-windsurf-board-guide'    => 'Fanatic',
  'advanced-kiteboarding-gear-guide' => 'Duotone',
  'beginner-wing-foil-gear'          => 'Duotone Echo',
  'intermediate-windsurfer-upgrade-guide' => 'Fanatic Blast',
  'what-size-kite-do-i-need'         => 'Duotone',
  'how-long-does-a-wetsuit-last'     => 'ION',
  'what-is-wing-foiling'             => 'Duotone',
  'can-you-kitesurf-without-lessons' => 'Duotone',
  'how-to-choose-a-sup-board'        => 'Fanatic Fly',
  'what-wetsuit-thickness-do-i-need' => 'ION Element',
}

attached = 0
skipped = 0

POST_IMAGE_MAP.each do |slug, search_term|
  post = Spree::Post.find_by(slug: slug)
  next unless post

  if post.image.attached?
    puts "#{slug}: already has image, skipping"
    skipped += 1
    next
  end

  # Find a product with this name that has images
  product = Spree::Product.where("name ILIKE ?", "%#{search_term}%")
                          .joins(:images)
                          .first

  unless product
    puts "#{slug}: no product found for '#{search_term}'"
    next
  end

  image = product.images.first
  unless image&.attachment&.attached?
    puts "#{slug}: product found but no image attached"
    next
  end

  begin
    # Download the existing image blob and re-attach to the post
    blob = image.attachment.blob
    post.image.attach(
      io: StringIO.new(blob.download),
      filename: "#{slug}-hero.#{blob.content_type.split('/').last}",
      content_type: blob.content_type
    )
    puts "#{slug}: attached image from #{product.name}"
    attached += 1
  rescue => e
    puts "#{slug}: ERROR #{e.message[0,80]}"
  end
end

puts "\nAttached #{attached} images, skipped #{skipped}"
