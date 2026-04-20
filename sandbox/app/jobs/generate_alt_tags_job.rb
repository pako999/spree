# frozen_string_literal: true
#
# Weekly job: fills in missing alt text on all Spree::Image records.
# Format: "<Product Name> - <Brand> <Category> | Surf-store.com"
# Skips images that already have alt text.
#
# Scheduled via config/recurring.yml  →  every Monday at 03:00
class GenerateAltTagsJob < ApplicationJob
  queue_as :background

  STORE_SUFFIX = 'Surf-store.com'

  def perform
    brand_tid = Spree::Taxonomy.find_by(name: 'Brands')&.id
    cat_tid   = Spree::Taxonomy.find_by(name: 'Categories')&.id

    # Preload all products + their taxons to avoid N+1
    products_by_id = Spree::Product.includes(taxons: [:taxonomy]).index_by(&:id)
    variants_by_id = {}
    Spree::Variant.unscoped.find_each(batch_size: 1000) { |v| variants_by_id[v.id] = v }

    updated = 0
    skipped = 0

    Spree::Image.where(alt: [nil, '']).in_batches(of: 500) do |batch|
      batch.each do |img|
        variant = variants_by_id[img.viewable_id]
        product = variant && products_by_id[variant.product_id]

        unless product
          skipped += 1
          next
        end

        alt = build_alt(product, brand_tid, cat_tid)
        next if alt.blank?

        Spree::Image.where(id: img.id).update_all(alt: alt)
        updated += 1
      end
    end

    Rails.logger.info "[GenerateAltTagsJob] done — updated=#{updated} skipped=#{skipped}"
  end

  private

  def build_alt(product, brand_tid, cat_tid)
    brand    = product.taxons.select { |t| t.taxonomy_id == brand_tid }.max_by { |t| t.depth.to_i }&.name
    category = product.taxons.select { |t| t.taxonomy_id == cat_tid  }.max_by { |t| t.depth.to_i }&.name

    parts = [product.name.to_s.strip]
    parts << brand    if brand    && !product.name.to_s.downcase.include?(brand.to_s.downcase)
    parts << category if category && !parts.join(' ').downcase.include?(category.to_s.downcase)

    alt = parts.compact.reject(&:empty?).join(' - ') + " | #{STORE_SUFFIX}"
    alt.length > 125 ? alt[0..124].rstrip : alt
  end
end
