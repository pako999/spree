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
      @author   = Spree.user_class.first
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
      # Batch tracking for rollback
      post.set_metafield('seo_batch_id', @batch_id, namespace: 'seo')

      # Schema
      post.set_metafield('schema_type', row['schema_type'].presence || 'Article', namespace: 'seo')
      post.set_metafield('schema_json', row['schema_json'].presence, namespace: 'seo') if row['schema_json'].present?

      # Related taxon permalinks — stored as JSON array
      if row['related_taxon_permalinks'].present?
        permalinks = row['related_taxon_permalinks'].split(',').map(&:strip)
        taxon_ids  = Spree::Taxon.where(permalink: permalinks).pluck(:id)
        post.set_metafield('related_taxon_ids', taxon_ids.to_json, namespace: 'seo')
      end

      # Related product SKUs — stored as JSON array
      if row['related_product_skus'].present?
        skus        = row['related_product_skus'].split(',').map(&:strip)
        product_ids = Spree::Variant.where(sku: skus).select(:product_id).map(&:product_id).uniq
        post.set_metafield('related_product_ids', product_ids.to_json, namespace: 'seo')
      end
    rescue => e
      Rails.logger.warn("[Seo::PostImporter] Metafield error for #{row['slug']}: #{e.message}")
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
