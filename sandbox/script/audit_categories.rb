# frozen_string_literal: true
# Audit: show each product, its current category taxons, and name for manual review
# Run: bin/kamal app exec --reuse "bin/rails runner /rails/script/audit_categories.rb"

categories_taxonomy = Spree::Taxonomy.find_by!(name: 'Categories')
brands_taxonomy     = Spree::Taxonomy.find_by!(name: 'Brands')

cat_taxon_ids   = categories_taxonomy.taxons.pluck(:id)
brand_taxon_ids = brands_taxonomy.taxons.pluck(:id)

puts "Total active products: #{Spree::Product.active.count}"
puts ""

# Group by their category taxons
by_category = Hash.new { |h, k| h[k] = [] }

Spree::Product.active.includes(:taxons).each do |p|
  cat_taxons = p.taxons.select { |t| cat_taxon_ids.include?(t.id) }
  label = cat_taxons.map(&:permalink).sort.join(' | ')
  label = '(NO CATEGORY)' if label.blank?
  by_category[label] << p
end

by_category.sort_by { |k, _| k }.each do |cat_label, products|
  puts "#{cat_label}  [#{products.size} products]"
  products.first(5).each do |p|
    brand_taxons = p.taxons.select { |t| brand_taxon_ids.include?(t.id) }.map(&:name).join(', ')
    puts "  [#{p.id}] #{p.name.truncate(70)}  (brand: #{brand_taxons})"
  end
  puts "  ... and #{products.size - 5} more" if products.size > 5
  puts ""
end
