# frozen_string_literal: true
# Seo::PostImporter — reads posts.csv and creates/updates Spree::Post records.
#
# CSV headers expected:
#   slug, title, meta_title, meta_description, meta_keywords,
#   category_slug, body_html, excerpt, hero_image_filename,
#   schema_type, schema_json, related_taxon_permalinks,
#   related_product_skus, published_at, batch_id
#
# Usage:
#   result = Seo::PostImporter.new('db/seo_data/batch_04_guides/posts.csv', batch_id: 'batch_04_guides').import
#   # => { created: 10, updated: 5, errors: 0 }

require 'csv'

module Seo
  class PostImporter
    IMAGES_DIR = Rails.root.join('db/seo_data/images')

    def initialize(csv_path, batch_id:)
      @csv_path = csv_path
      @batch_id = batch_id
      @store    = Spree::Store.find(2)
      @author   = Spree.admin_user_class.first
    end

    def import
      rows = CSV.read(@csv_path, headers: true, encoding: 'UTF-8').map(&:to_h)
      created = updated = errors = 0

      rows.each do |row|
        begin
          post = build_post(row)
          is_new = post.new_record?
          post.save!

          attach_hero_image(post, row['hero_image_filename']) if row['hero_image_filename'].present?
          attach_image_from_products(post, row['related_product_skus']) unless post.image.attached?
          attach_image_from_taxons(post, row['related_taxon_permalinks']) unless post.image.attached?
          set_metafields(post, row)

          is_new ? (created += 1; print 'C') : (updated += 1; print 'U')
        rescue => e
          errors += 1
          Rails.logger.error("[Seo::PostImporter] #{row['slug']}: #{e.message}\n#{e.backtrace.first(3).join("\n")}")
          print 'E'
        end
      end

      puts ''
      { created: created, updated: updated, errors: errors }
    end

    private

    def build_post(row)
      post = Spree::Post.with_deleted.friendly.find_by(slug: row['slug']) ||
             Spree::Post.new

      post.restore(recursive: true) if post.deleted_at.present?

      post.store        = @store
      post.author       = @author
      post.title        = row['title']
      post.slug         = row['slug']
      post.meta_title   = row['meta_title'].presence
      post.meta_description = row['meta_description'].presence

      # Assign post category
      category_slug = row['category_slug'].presence || 'articles'
      category = Spree::PostCategory.find_by(slug: category_slug)
      post.post_category = category if category

      # Set ActionText rich content
      post.content = row['body_html'].presence || row['excerpt'].presence || ''

      # Published at
      if row['published_at'].present?
        post.published_at = Time.zone.parse(row['published_at'])
      else
        post.published_at ||= Time.current
      end

      post
    end

    def set_metafields(post, row)
      post.set_metafield('seo.seo_batch_id', @batch_id)
      post.set_metafield('seo.schema_type', row['schema_type'].presence || 'Article')
      post.set_metafield('seo.meta_keywords', row['meta_keywords'].presence) if row['meta_keywords'].present?
      post.set_metafield('seo.schema_json', row['schema_json'].presence) if row['schema_json'].present?

      if row['related_taxon_permalinks'].present?
        permalinks = row['related_taxon_permalinks'].split(',').map(&:strip)
        taxon_ids  = Spree::Taxon.where(permalink: permalinks).pluck(:id)
        post.set_metafield('seo.related_taxon_ids', taxon_ids.to_json)
      end

      if row['related_product_skus'].present?
        skus        = row['related_product_skus'].split(',').map(&:strip)
        product_ids = Spree::Variant.where(sku: skus).select(:product_id).map(&:product_id).uniq
        post.set_metafield('seo.related_product_ids', product_ids.to_json)
      end
    rescue => e
      Rails.logger.warn("[Seo::PostImporter] Metafield error for #{row['slug']}: #{e.message}")
    end

    def attach_image_from_products(post, skus_str)
      return if skus_str.blank?
      skus = skus_str.split(',').map(&:strip)
      product_ids = Spree::Variant.where(sku: skus).pluck(:product_id).uniq
      return if product_ids.empty?

      product = Spree::Product.includes(master: :images).find(product_ids.first)
      source_img = product.images.first || product.master.images.first
      return unless source_img&.attachment&.attached?

      blob = source_img.attachment.blob
      post.image.attach(blob)
    rescue => e
      Rails.logger.warn("[Seo::PostImporter] Product image attach failed for #{post.slug}: #{e.message}")
    end

    def attach_image_from_taxons(post, permalinks_str)
      return if permalinks_str.blank?
      permalinks = permalinks_str.split(',').map(&:strip)

      # Use post slug checksum to pick a different offset per post — avoids all posts getting the same image
      slug_offset = post.slug.bytes.sum

      permalinks.each do |permalink|
        taxon = Spree::Taxon.find_by(permalink: permalink)
        next unless taxon

        # Collect all master_ids for products in this taxon that have images
        master_ids = taxon.products.pluck(:id).map do |pid|
          Spree::Variant.where(product_id: pid, is_master: true).pick(:id)
        end.compact

        next if master_ids.empty?

        # Rotate through available images, skipping placeholders
        img_ids = Spree::Image.where(viewable_type: 'Spree::Variant', viewable_id: master_ids)
                              .joins(:attachment)
                              .where.not('active_storage_blobs.filename ILIKE ?', '%coming_soon%')
                              .where.not('active_storage_blobs.filename ILIKE ?', '%placeholder%')
                              .pluck(:id)
        next if img_ids.empty?

        img = Spree::Image.find(img_ids[slug_offset % img_ids.size])
        next unless img.attachment.attached?

        post.image.attach(img.attachment.blob)
        return
      end
    rescue => e
      Rails.logger.warn("[Seo::PostImporter] Taxon image attach failed for #{post.slug}: #{e.message}")
    end

    def attach_hero_image(post, filename)
      path = Dir.glob(IMAGES_DIR.join('**', filename)).first
      return unless path && File.exist?(path)
      return if post.image.attached? && post.image.blob.filename.to_s == filename

      post.image.attach(
        io:           File.open(path),
        filename:     filename,
        content_type: Marcel::MimeType.for(Pathname.new(path))
      )
    rescue => e
      Rails.logger.warn("[Seo::PostImporter] Image attach failed for #{filename}: #{e.message}")
    end
  end
end
