# Assign products to brand sub-taxons based on product name matching
# Products already belong to parent brand taxons — this adds them to the sub-categories too
# Run: kamal app exec --reuse "bin/rails runner /rails/script/assign_products_to_brand_subtaxons.rb"

RULES = {
  # NeilPryde sub-taxons
  'brands/neilpryde/wetsuits' => { parent: 'brands/neilpryde', match: /wetsuit|neoprene|wizard|mission/i, exclude: /sail|mast|boom|wing|foil/i },
  'brands/neilpryde/masts'    => { parent: 'brands/neilpryde', match: /mast/i },
  'brands/neilpryde/wings'    => { parent: 'brands/neilpryde', match: /wing/i, exclude: /sail|mast/i },

  # ION sub-taxons
  'brands/ion/wetsuits'   => { parent: 'brands/ion', match: /wetsuit|element|seek|amaze|base.*\d\/\d|shorty|steamer/i, exclude: /harness|helmet|pad|boot|glove|vest|bag/i },
  'brands/ion/harnesses'  => { parent: 'brands/ion', match: /harness|riot|apex|radar|radium/i, exclude: /wetsuit|line/i },
  'brands/ion/boots'      => { parent: 'brands/ion', match: /boot|shoe|slipper|ballistic.*shoe/i },

  # Cabrinha sub-taxons
  'brands/cabrinha/bars'    => { parent: 'brands/cabrinha', match: /bar|control|unify|1x/i, exclude: /kite(?!.*bar)|board/i },
  'brands/cabrinha/boards'  => { parent: 'brands/cabrinha', match: /board|spectrum|ace|xcaliber|tronic/i, exclude: /kite|bar/i },

  # Duotone Wing Foiling sub-taxons
  'brands/duotone-wing-foiling/foils'  => { parent: 'brands/duotone-wing-foiling', match: /foil|spirit|glide.*mast|fuselage|stabiliz/i, exclude: /wing(?!.*foil)|board/i },
  'brands/duotone-wing-foiling/boards' => { parent: 'brands/duotone-wing-foiling', match: /board|pace|sky.*wing/i, exclude: /wing(?!.*board)|foil(?!.*board)/i },

  # Duotone Kiteboarding sub-taxons
  'brands/duotone-kiteboarding/harnesses' => { parent: 'brands/duotone-kiteboarding', match: /harness|apex|radar/i, exclude: /kite|bar|board/i },

  # Fanatic sub-taxons
  'brands/fanatic-sup/boards'          => { parent: 'brands/fanatic-sup', match: /./i },
  'brands/fanatic-windsurfing/boards'  => { parent: 'brands/fanatic-windsurfing', match: /./i },

  # Gaastra sails
  'brands/gaastra/sails' => { parent: 'brands/gaastra', match: /sail|cosmic|matrix|boost|vapor/i, exclude: /board|harness|kite(?!.*sail)/i },

  # Nobile sub-taxons
  'brands/nobile/kiteboards' => { parent: 'brands/nobile', match: /board|nhp|50fifty|t5|infinity/i, exclude: /foil/i },
  'brands/nobile/foils'      => { parent: 'brands/nobile', match: /foil|hydrofoil/i },

  # Point-7 sails
  'brands/point7/sails' => { parent: 'brands/point7', match: /./i },

  # Tabou boards
  'brands/tabou/boards' => { parent: 'brands/tabou', match: /./i },
}

total_assigned = 0

RULES.each do |permalink, rule|
  taxon = Spree::Taxon.find_by(permalink: permalink)
  parent = Spree::Taxon.find_by(permalink: rule[:parent])
  next unless taxon && parent

  # Get products from parent brand taxon
  parent_products = parent.products.active

  matched = parent_products.select do |p|
    name = p.name.to_s
    matches_include = name.match?(rule[:match])
    matches_exclude = rule[:exclude] ? name.match?(rule[:exclude]) : false
    matches_include && !matches_exclude
  end

  # Assign products to sub-taxon (skip if already assigned)
  assigned = 0
  matched.each do |product|
    unless product.taxons.include?(taxon)
      product.taxons << taxon
      assigned += 1
    end
  end

  total_assigned += assigned
  puts "#{permalink.ljust(50)} +#{assigned} products (#{matched.size} matched, #{taxon.products.reload.count} total)"
end

puts "\nTotal: #{total_assigned} product-taxon assignments created"
