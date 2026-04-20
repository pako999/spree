# frozen_string_literal: true
#
# Weekly job: fills in missing meta_title / meta_description for products,
# taxons (Categories / Brands / Collections) and the homepage.
# Safe to run repeatedly — only touches records where the field is blank.
#
# Scheduled via config/recurring.yml  →  every Monday at 02:00
class GenerateSeoMetaJob < ApplicationJob
  queue_as :background

  STORE_SUFFIX  = 'Surf-store.com'

  def perform
    brand_tid = Spree::Taxonomy.find_by(name: 'Brands')&.id
    cat_tid   = Spree::Taxonomy.find_by(name: 'Categories')&.id

    fill_homepage
    counts = fill_taxons
    counts.merge!(fill_products(brand_tid, cat_tid))

    Rails.logger.info "[GenerateSeoMetaJob] done — #{counts.inspect}"
  end

  private

  # ── Homepage ──────────────────────────────────────────────────────────────

  def fill_homepage
    hp = Spree::Page.find_by(type: 'Spree::Pages::Homepage')
    return unless hp

    changed = false
    if hp.meta_title.blank?
      hp.meta_title = "Surf-store.com | Windsurfing, Kitesurfing & Water Sports Shop"
      changed = true
    end
    if hp.meta_description.blank?
      hp.meta_description = "Europe's online surf shop. Buy windsurfing, kitesurfing, wingfoil & SUP gear from top brands like Duotone, ION, Fanatic & more. Free shipping. Official dealer."
      changed = true
    end
    hp.save!(touch: false) if changed
  end

  # ── Taxons ────────────────────────────────────────────────────────────────

  def fill_taxons
    seo_taxonomies = Spree::Taxonomy.where(name: %w[Categories Brands Collections]).pluck(:id)
    taxons = Spree::Taxon.where(taxonomy_id: seo_taxonomies).includes(:taxonomy, :parent)
    title_count = 0
    desc_count  = 0

    taxons.find_each do |t|
      next if t.parent_id.nil?  # skip root nodes

      taxonomy_name = t.taxonomy&.name
      parent_name   = t.parent&.name
      changed = false

      if t.meta_title.blank?
        t.meta_title = taxon_title(t.name, taxonomy_name, parent_name, taxonomy_name)
        changed = true
        title_count += 1
      end

      if t.meta_description.blank?
        t.meta_description = taxon_description(t.name, taxonomy_name)
        changed = true
        desc_count += 1
      end

      t.save!(touch: false) if changed
    end

    { taxon_titles: title_count, taxon_descs: desc_count }
  end

  def taxon_title(name, taxonomy_name, parent_name, _taxonomy)
    title = case taxonomy_name
            when 'Brands'
              "#{name} | #{STORE_SUFFIX}"
            when 'Categories'
              parent = (parent_name && parent_name != taxonomy_name) ? parent_name : nil
              parent ? "#{name} #{parent} | #{STORE_SUFFIX}" : "#{name} | Shop at #{STORE_SUFFIX}"
            else
              "#{name} | #{STORE_SUFFIX}"
            end
    title[0..59]
  end

  def taxon_description(name, taxonomy_name)
    desc = case taxonomy_name
           when 'Brands'
             "Shop #{name} gear at #{STORE_SUFFIX}. Official dealer with the full #{name} range. Free shipping in Europe."
           when 'Categories'
             "Buy #{name} online at #{STORE_SUFFIX}. Wide selection from top brands. Free shipping in Europe. Official dealer."
           else
             "Browse #{name} at #{STORE_SUFFIX}. Free shipping in Europe."
           end
    desc[0..159]
  end

  # ── Products ──────────────────────────────────────────────────────────────

  def fill_products(brand_tid, cat_tid)
    title_count = 0
    desc_count  = 0

    Spree::Product.where(status: 'active').includes(taxons: [:taxonomy]).find_each(batch_size: 200) do |p|
      changed = false

      if p.meta_title.blank?
        p.meta_title = product_title(p, brand_tid, cat_tid)
        changed = true
        title_count += 1
      end

      if p.meta_description.blank?
        p.meta_description = product_description(p, brand_tid, cat_tid)
        changed = true
        desc_count += 1
      end

      p.save!(touch: false) if changed
    end

    { product_titles: title_count, product_descs: desc_count }
  end

  def product_title(product, brand_tid, cat_tid)
    brand    = product.taxons.select { |t| t.taxonomy_id == brand_tid }.max_by { |t| t.depth.to_i }&.name
    category = product.taxons.select { |t| t.taxonomy_id == cat_tid  }.max_by { |t| t.depth.to_i }&.name

    parts = [product.name.strip]
    parts << brand    if brand    && !product.name.downcase.include?(brand.downcase)
    parts << category if category && !parts.join(' ').downcase.include?(category.downcase)

    meta = parts.join(' | ') + " - Buy at #{STORE_SUFFIX}"
    if meta.length > 60
      meta = parts.join(' | ')
      meta = meta.length > 55 ? "#{product.name.strip} | #{STORE_SUFFIX}" : "#{meta} | #{STORE_SUFFIX}"
    end
    meta[0..59]
  end

  def product_description(product, brand_tid, cat_tid)
    if product.description.present?
      clean = ActionController::Base.helpers.strip_tags(product.description.to_s).gsub(/\s+/, ' ').strip
      if clean.length > 140
        meta = clean[0..139].sub(/\s+\S*$/, '') + "... | Shop at #{STORE_SUFFIX}"
      else
        meta = clean + " | Shop at #{STORE_SUFFIX}"
      end
    else
      brand    = product.taxons.select { |t| t.taxonomy_id == brand_tid }.max_by { |t| t.depth.to_i }&.name
      category = product.taxons.select { |t| t.taxonomy_id == cat_tid  }.max_by { |t| t.depth.to_i }&.name
      meta = "Buy #{product.name}"
      meta += " by #{brand}"    if brand
      meta += " in #{category}" if category
      meta += ". Free shipping in Europe. Official dealer. | #{STORE_SUFFIX}"
    end
    meta[0..159]
  end
end
