#!/usr/bin/env ruby
# Generate SEO meta_title and meta_description for products, taxons, and homepage.
# Safe to re-run — skips records that already have values set.
#
# Run via: kamal app exec --reuse "bin/rails runner script/generate_meta.rb"

require 'action_view'
include ActionView::Helpers::SanitizeHelper

STORE_SUFFIX = 'Surf-store.com'
STORE_TAGLINE = "Windsurfing, Kitesurfing & Water Sports | #{STORE_SUFFIX}"

brand_tid = Spree::Taxonomy.find_by(name: 'Brands')&.id
cat_tid   = Spree::Taxonomy.find_by(name: 'Categories')&.id

# ─── HOMEPAGE ────────────────────────────────────────────────────────────────
puts "=== Homepage ==="
hp = Spree::Page.find_by(type: 'Spree::Pages::Homepage')
if hp
  changed = false
  if hp.meta_title.blank?
    hp.meta_title = "Surf-store.com | Windsurfing, Kitesurfing & Water Sports Shop"
    changed = true
    puts "  Set meta_title"
  end
  if hp.meta_description.blank?
    hp.meta_description = "Europe's online surf shop. Buy windsurfing, kitesurfing, wingfoil & SUP gear from top brands like Duotone, ION, Fanatic & more. Free shipping. Official dealer."
    changed = true
    puts "  Set meta_description"
  end
  hp.save!(touch: false) if changed
  puts changed ? "  Saved." : "  Already set — skipped."
else
  puts "  Homepage page not found."
end
puts

# ─── TAXONS (Categories, Brands, Collections only — skip Tags) ───────────────
puts "=== Taxons ==="
seo_taxonomies = Spree::Taxonomy.where(name: %w[Categories Brands Collections]).pluck(:id)
taxons = Spree::Taxon.where(taxonomy_id: seo_taxonomies).includes(:taxonomy, :parent)
taxon_title_updated = 0
taxon_desc_updated  = 0

taxons.find_each do |t|
  # Skip root nodes (taxonomy name = taxon name)
  next if t.parent_id.nil?

  changed = false
  taxonomy_name = t.taxonomy&.name
  parent_name   = t.parent&.name

  if t.meta_title.blank?
    title = case taxonomy_name
            when 'Brands'
              "#{t.name} | #{STORE_SUFFIX}"
            when 'Categories'
              parent = (parent_name && parent_name != taxonomy_name) ? parent_name : nil
              parent ? "#{t.name} #{parent} | #{STORE_SUFFIX}" : "#{t.name} | Shop at #{STORE_SUFFIX}"
            else
              "#{t.name} | #{STORE_SUFFIX}"
            end
    t.meta_title = title[0..59]
    changed = true
    taxon_title_updated += 1
  end

  if t.meta_description.blank?
    desc = case taxonomy_name
           when 'Brands'
             "Shop #{t.name} gear at #{STORE_SUFFIX}. Official dealer with the full #{t.name} range. Free shipping in Europe."
           when 'Categories'
             "Buy #{t.name} online at #{STORE_SUFFIX}. Wide selection from top brands. Free shipping in Europe. Official dealer."
           else
             "Browse #{t.name} at #{STORE_SUFFIX}. Free shipping in Europe."
           end
    t.meta_description = desc[0..159]
    changed = true
    taxon_desc_updated += 1
  end

  t.save!(touch: false) if changed
end

puts "  Taxon meta_titles  added: #{taxon_title_updated}"
puts "  Taxon meta_descs   added: #{taxon_desc_updated}"
puts

# ─── PRODUCTS ────────────────────────────────────────────────────────────────
puts "=== Products ==="
products = Spree::Product.where(status: 'active').includes(taxons: [:taxonomy])
total = products.count
title_updated = 0
desc_updated  = 0

products.find_each(batch_size: 200) do |p|
  changed = false

  # --- META TITLE ---
  if p.meta_title.blank?
    brand    = p.taxons.select { |t| t.taxonomy_id == brand_tid }
                       .max_by { |t| t.depth.to_i }&.name
    category = p.taxons.select { |t| t.taxonomy_id == cat_tid }
                        .max_by { |t| t.depth.to_i }&.name

    parts = [p.name.strip]
    parts << brand    if brand    && !p.name.downcase.include?(brand.downcase)
    parts << category if category && !parts.join(' ').downcase.include?(category.downcase)

    meta_title = parts.join(' | ') + " - Buy at #{STORE_SUFFIX}"
    if meta_title.length > 60
      meta_title = parts.join(' | ')
      meta_title = meta_title.length > 55 ? "#{p.name.strip} | #{STORE_SUFFIX}" : "#{meta_title} | #{STORE_SUFFIX}"
    end
    meta_title = meta_title[0..59] if meta_title.length > 60

    p.meta_title = meta_title
    changed = true
    title_updated += 1
  end

  # --- META DESCRIPTION ---
  if p.meta_description.blank?
    if p.description.present?
      clean = strip_tags(p.description.to_s).gsub(/\s+/, ' ').strip
      if clean.length > 140
        meta_desc = clean[0..139].sub(/\s+\S*$/, '') + "... | Shop at #{STORE_SUFFIX}"
      else
        meta_desc = clean + " | Shop at #{STORE_SUFFIX}"
      end
    else
      brand    = p.taxons.select { |t| t.taxonomy_id == brand_tid }
                         .max_by { |t| t.depth.to_i }&.name
      category = p.taxons.select { |t| t.taxonomy_id == cat_tid }
                          .max_by { |t| t.depth.to_i }&.name
      meta_desc = "Buy #{p.name}"
      meta_desc += " by #{brand}"    if brand
      meta_desc += " in #{category}" if category
      meta_desc += ". Free shipping in Europe. Official dealer. | #{STORE_SUFFIX}"
    end
    p.meta_description = meta_desc[0..159]
    changed = true
    desc_updated += 1
  end

  p.save!(touch: false) if changed
  print "." if (title_updated + desc_updated) % 100 == 0
end

puts
puts "=" * 60
puts "Products processed     : #{total}"
puts "Product titles added   : #{title_updated}"
puts "Product descs added    : #{desc_updated}"
puts "Taxon titles added     : #{taxon_title_updated}"
puts "Taxon descs added      : #{taxon_desc_updated}"
puts "Homepage               : done"
