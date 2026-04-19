# frozen_string_literal: true
# Fix product categories across all brands
# Run: copy to container then bin/rails runner /tmp/fix_product_categories.rb

cat_tax   = Spree::Taxonomy.find_by!(name: 'Categories')
brand_tax = Spree::Taxonomy.find_by!(name: 'Brands')

# Helpers
def taxon(permalink)
  @taxon_cache ||= {}
  @taxon_cache[permalink] ||= Spree::Taxon.find_by(permalink: permalink)
end

def add_taxons(product, *permalinks)
  permalinks.each do |pl|
    t = taxon(pl)
    unless t
      puts "  ⚠ taxon not found: #{pl}"
      next
    end
    unless product.taxons.include?(t)
      product.taxons << t
      puts "  + #{pl}"
    end
  end
end

def remove_taxon(product, permalink)
  t = taxon(permalink)
  return unless t
  if product.taxons.include?(t)
    product.taxons.delete(t)
    puts "  - #{permalink}"
  end
end

fixed = 0

puts "=" * 60
puts "FIX 1: Products with NO category taxon"
puts "=" * 60

{
  1615 => ['categories/windsurf', 'categories/windsurf/windsurf-boards', 'categories/windsurf/windsurf-boards/windsurf-board'],
  622  => ['categories/wingfoil', 'categories/wingfoil/wing-boards', 'categories/wingfoil/wing-boards/wingboard'],
  605  => ['categories/wingfoil', 'categories/wingfoil/wing-accessories', 'categories/wingfoil/wing-accessories/foil-bag'],
  2327 => ['categories/kitesurfing', 'categories/kitesurfing/kite-harnesses', 'categories/kitesurfing/kite-harnesses/harness'],
  603  => ['categories/kitesurfing', 'categories/kitesurfing/kite-accessories', 'categories/kitesurfing/kite-accessories/spare-parts'],
  609  => ['categories/windsurf', 'categories/windsurf/windsurf-accessories', 'categories/windsurf/windsurf-accessories/windsurf-bag'],
  6335 => ['categories/kitesurfing', 'categories/kitesurfing/kite-accessories', 'categories/kitesurfing/kite-accessories/kite-bar'],
  6334 => ['categories/kitesurfing', 'categories/kitesurfing/kite-accessories', 'categories/kitesurfing/kite-accessories/kite-bar'],
  951  => ['categories/kitesurfing', 'categories/kitesurfing/kite-accessories', 'categories/kitesurfing/kite-accessories/spare-parts'],
  607  => ['categories/kitesurfing', 'categories/kitesurfing/kite-accessories', 'categories/kitesurfing/kite-accessories/spare-parts'],
  899  => ['categories/kitesurfing', 'categories/kitesurfing/kite-accessories', 'categories/kitesurfing/kite-accessories/kite-bar'],
  5924 => ['categories/kitesurfing', 'categories/kitesurfing/kite-accessories', 'categories/kitesurfing/kite-accessories/leash'],
}.each do |id, permalinks|
  p = Spree::Product.find_by(id: id)
  next unless p
  puts "\n[#{id}] #{p.name}"
  add_taxons(p, *permalinks)
  fixed += 1
end

puts "\n" + "=" * 60
puts "FIX 2: Apparel-only products → add subcategory"
puts "=" * 60

cap_ids = [6301, 6302, 6303, 6304, 6305]
cap_ids.each do |id|
  p = Spree::Product.find_by(id: id)
  next unless p
  puts "\n[#{id}] #{p.name}"
  add_taxons(p, 'categories/apparel/cap')
  fixed += 1
end

# Doormat - move out of apparel into kite accessories
doormat = Spree::Product.find_by(id: 1326)
if doormat
  puts "\n[1326] #{doormat.name}"
  remove_taxon(doormat, 'categories/apparel')
  add_taxons(doormat, 'categories/kitesurfing', 'categories/kitesurfing/kite-accessories', 'categories/kitesurfing/kite-accessories/spare-parts')
  fixed += 1
end

# Tricktionary book
trick = Spree::Product.find_by(id: 1199)
if trick
  puts "\n[1199] #{trick.name}"
  add_taxons(trick, 'categories/kitesurfing', 'categories/kitesurfing/kite-accessories', 'categories/kitesurfing/kite-accessories/spare-parts')
  fixed += 1
end

puts "\n" + "=" * 60
puts "FIX 3: ION Bike products incorrectly in wetsuits"
puts "=" * 60

wetsuit_ids = [
  Spree::Taxon.find_by!(permalink: 'categories/wetsuits').id,
  Spree::Taxon.find_by!(permalink: 'categories/wetsuits/women-wetsuits').id,
]

ion_bike_brand = Spree::Taxon.find_by(permalink: 'brands/ion-bike')
if ion_bike_brand
  ion_bike_products = Spree::Product.joins(:taxons).where(spree_taxons: { id: ion_bike_brand.id }).distinct
  ion_bike_products.each do |p|
    product_taxon_ids = p.taxons.pluck(:id)
    in_wetsuits = wetsuit_ids.any? { |wid| product_taxon_ids.include?(wid) }
    next unless in_wetsuits

    # Only fix if they DON'T have a proper wetsuit subcategory
    # (some ION Bike products may genuinely have wetsuits e.g. neo tops)
    has_wetsuit_sub = p.taxons.any? { |t| t.permalink.start_with?('categories/wetsuits/') && t.depth >= 2 && !['categories/wetsuits/women-wetsuits', 'categories/wetsuits/men-wetsuits'].include?(t.permalink) }
    next if has_wetsuit_sub

    puts "\n[#{p.id}] #{p.name}"
    remove_taxon(p, 'categories/wetsuits')
    remove_taxon(p, 'categories/wetsuits/women-wetsuits')
    fixed += 1
  end
end

puts "\n" + "=" * 60
puts "FIX 4: Tabou 2026 windsurf boards - add windsurf-board subcategory"
puts "=" * 60

windsurf_boards_parent = Spree::Taxon.find_by!(permalink: 'categories/windsurf/windsurf-boards')
windsurf_board_sub     = Spree::Taxon.find_by!(permalink: 'categories/windsurf/windsurf-boards/windsurf-board')

Spree::Product.active.joins(:taxons).where(spree_taxons: { id: windsurf_boards_parent.id }).distinct.each do |p|
  next if p.taxons.include?(windsurf_board_sub)
  puts "\n[#{p.id}] #{p.name}"
  add_taxons(p, 'categories/windsurf/windsurf-boards/windsurf-board')
  fixed += 1
end

puts "\n" + "=" * 60
puts "FIX 5: GA Kites in parent kites/ - add kites/kite subcategory"
puts "=" * 60

kites_parent = Spree::Taxon.find_by!(permalink: 'categories/kitesurfing/kites')
kites_sub    = Spree::Taxon.find_by!(permalink: 'categories/kitesurfing/kites/kite')

Spree::Product.active.joins(:taxons).where(spree_taxons: { id: kites_parent.id }).distinct.each do |p|
  next if p.taxons.include?(kites_sub)
  # Only add kite subcategory to actual kites (not accessories/bars/bags)
  next unless p.name =~ /kite|parawing/i
  next if p.name =~ /bar|bag|line|pump|part|leash|strap/i
  puts "\n[#{p.id}] #{p.name}"
  add_taxons(p, 'categories/kitesurfing', 'categories/kitesurfing/kites/kite')
  fixed += 1
end

puts "\n" + "=" * 60
puts "FIX 6: GA Sails in windsurf-sails parent - add windsurfing-sails subcategory"
puts "=" * 60

ws_sails_parent = Spree::Taxon.find_by!(permalink: 'categories/windsurf/windsurf-sails')
ws_sails_sub    = Spree::Taxon.find_by!(permalink: 'categories/windsurf/windsurf-sails/windsurfing-sails')

Spree::Product.active.joins(:taxons).where(spree_taxons: { id: ws_sails_parent.id }).distinct.each do |p|
  next if p.taxons.include?(ws_sails_sub)
  puts "\n[#{p.id}] #{p.name}"
  add_taxons(p, 'categories/windsurf', 'categories/windsurf/windsurf-sails/windsurfing-sails')
  fixed += 1
end

puts "\n" + "=" * 60
puts "FIX 7: GA Windsurf accessories - add specific subcategories by name"
puts "=" * 60

ws_accessories_parent = Spree::Taxon.find_by!(permalink: 'categories/windsurf/windsurf-accessories')

Spree::Product.active.joins(:taxons).where(spree_taxons: { id: ws_accessories_parent.id }).distinct.each do |p|
  name = p.name.downcase
  current_subs = p.taxons.map(&:permalink)

  if name =~ /harness line|harness lines/ && !current_subs.any? { |t| t.include?('spare-part-for-harness') }
    puts "\n[#{p.id}] #{p.name}"
    add_taxons(p, 'categories/windsurf/windsurf-harnesses', 'categories/windsurf/windsurf-harnesses/spare-part-for-harness')
    fixed += 1
  elsif name =~ /bag|boardbag|quiver/ && !current_subs.any? { |t| t.include?('windsurf-bag') }
    puts "\n[#{p.id}] #{p.name}"
    add_taxons(p, 'categories/windsurf/windsurf-accessories/windsurf-bag')
    fixed += 1
  elsif name =~ /extension/ && !current_subs.any? { |t| t.include?('windsurf-extension') }
    puts "\n[#{p.id}] #{p.name}"
    add_taxons(p, 'categories/windsurf/windsurf-gear', 'categories/windsurf/windsurf-gear/windsurf-extension')
    fixed += 1
  end
end

puts "\n" + "=" * 60
puts "FIX 8: Kitesurfing parent-only bags/accessories - add spare-parts subcategory"
puts "=" * 60

kite_parent = Spree::Taxon.find_by!(permalink: 'categories/kitesurfing')
kite_spare  = Spree::Taxon.find_by!(permalink: 'categories/kitesurfing/kite-accessories/spare-parts')
kite_acc    = Spree::Taxon.find_by!(permalink: 'categories/kitesurfing/kite-accessories')

cat_ids = cat_tax.taxons.pluck(:id)

Spree::Product.active.joins(:taxons).where(spree_taxons: { id: kite_parent.id }).distinct.each do |p|
  cat_taxons = p.taxons.select { |t| cat_ids.include?(t.id) }
  # Only products that are ONLY in the kitesurfing parent (no deeper subcategory)
  next unless cat_taxons.all? { |t| t.permalink == 'categories/kitesurfing' }

  name = p.name.downcase
  puts "\n[#{p.id}] #{p.name}"
  if name =~ /bag|boardbag|crushbag|gearbag|day bag|quiver/
    add_taxons(p, 'categories/kitesurfing/kite-accessories', 'categories/kitesurfing/kite-accessories/spare-parts')
  elsif name =~ /hook/
    add_taxons(p, 'categories/kitesurfing/kite-accessories', 'categories/kitesurfing/kite-accessories/spare-parts')
  else
    add_taxons(p, 'categories/kitesurfing/kite-accessories', 'categories/kitesurfing/kite-accessories/spare-parts')
  end
  fixed += 1
end

puts "\n" + "=" * 60
puts "FIX 9: Point7 products in windsurf-mast that are not masts"
puts "=" * 60

mast_taxon = Spree::Taxon.find_by!(permalink: 'categories/windsurf/windsurf-gear/windsurf-mast')

Spree::Product.active.joins(:taxons).where(spree_taxons: { id: mast_taxon.id }).distinct.each do |p|
  name = p.name.downcase
  next if name =~ /mast/  # genuine mast product, skip

  puts "\n[#{p.id}] #{p.name}"

  if name =~ /harness/ && !name =~ /harness line/
    add_taxons(p, 'categories/windsurf/windsurf-harnesses', 'categories/windsurf/windsurf-harnesses/windsurf-harness')
  elsif name =~ /harness line/
    add_taxons(p, 'categories/windsurf/windsurf-harnesses', 'categories/windsurf/windsurf-harnesses/spare-part-for-harness')
  elsif name =~ /boom/
    add_taxons(p, 'categories/windsurf/windsurf-gear', 'categories/windsurf/windsurf-gear/windsurf-boom')
  elsif name =~ /sail|crossride|freeride|slalom|wave|freestyle/
    add_taxons(p, 'categories/windsurf/windsurf-sails', 'categories/windsurf/windsurf-sails/windsurfing-sails')
  elsif name =~ /extension/
    add_taxons(p, 'categories/windsurf/windsurf-gear', 'categories/windsurf/windsurf-gear/windsurf-extension')
  elsif name =~ /bag|quiver|fin bag/
    add_taxons(p, 'categories/windsurf/windsurf-accessories', 'categories/windsurf/windsurf-accessories/windsurf-bag')
  elsif name =~ /fin/
    add_taxons(p, 'categories/windsurf/windsurf-accessories', 'categories/windsurf/windsurf-accessories/surf-fins')
  elsif name =~ /base/
    add_taxons(p, 'categories/windsurf/windsurf-gear', 'categories/windsurf/windsurf-gear/bases')
  else
    add_taxons(p, 'categories/windsurf/windsurf-accessories', 'categories/windsurf/windsurf-accessories/windsurf-spare-parts')
  end
  fixed += 1
end

puts "\n" + "=" * 60
puts "FIX 10: Wingfoil parent-only products - add wing-accessories subcategory"
puts "=" * 60

wing_parent = Spree::Taxon.find_by!(permalink: 'categories/wingfoil')

Spree::Product.active.joins(:taxons).where(spree_taxons: { id: wing_parent.id }).distinct.each do |p|
  cat_taxons = p.taxons.select { |t| cat_ids.include?(t.id) }
  next unless cat_taxons.all? { |t| t.permalink == 'categories/wingfoil' }

  name = p.name.downcase
  puts "\n[#{p.id}] #{p.name}"

  if name =~ /bag|boardbag|gearbag/
    add_taxons(p, 'categories/wingfoil/wing-accessories', 'categories/wingfoil/wing-accessories/wing-bags')
  elsif name =~ /foil bag/
    add_taxons(p, 'categories/wingfoil/wing-accessories', 'categories/wingfoil/wing-accessories/foil-bag')
  elsif name =~ /leash/
    add_taxons(p, 'categories/wingfoil/wing-accessories', 'categories/wingfoil/wing-accessories/wing-leash')
  elsif name =~ /bladder/
    add_taxons(p, 'categories/wingfoil/wing-accessories', 'categories/wingfoil/wing-accessories/wing-bladder')
  else
    add_taxons(p, 'categories/wingfoil/wing-accessories')
  end
  fixed += 1
end

puts "\n" + "=" * 60
puts "Done. Products updated: #{fixed}"
puts "=" * 60
