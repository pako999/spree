# frozen_string_literal: true
# Seo::TaxonImporter — reads taxons.csv and creates/updates Spree::Taxon records.
#
# CSV headers expected:
#   permalink, name, parent_permalink, depth, meta_title, meta_description,
#   meta_keywords, description_html, hero_image_filename, icon_filename, batch_id
#
# Usage:
#   result = Seo::TaxonImporter.new('db/seo_data/batch_01_brands/taxons.csv', batch_id: 'batch_01_brands').import
#   # => { created: 10, updated: 5, errors: 0 }

require 'csv'

module Seo
  class TaxonImporter
    IMAGES_DIR = Rails.root.join('db/seo_data/images')

    def initialize(csv_path, batch_id:)
      @csv_path = csv_path
      @batch_id = batch_id
    end

    def import
      rows = load_rows
      # Sort by depth so parents always exist before children
      rows.sort_by! { |r| r['depth'].to_i }

      created = updated = errors = 0

      rows.each do |row|
        begin
          taxon = build_taxon(row)
          if taxon.new_record?
            taxon.save!
            created += 1
            print 'C'
          else
            taxon.save!
            updated += 1
            print 'U'
          end

          attach_hero_image(taxon, row['hero_image_filename']) if row['hero_image_filename'].present?
        rescue => e
          errors += 1
          Rails.logger.error("[Seo::TaxonImporter] #{row['permalink']}: #{e.message}")
          print 'E'
        end
      end

      puts ''
      { created: created, updated: updated, errors: errors }
    end

    private

    def load_rows
      CSV.read(@csv_path, headers: true, encoding: 'UTF-8').map(&:to_h)
    end

    def build_taxon(row)
      categories_taxonomy = Spree::Taxonomy.find_by!(name: 'Categories')

      # Determine taxonomy from permalink prefix
      taxonomy = if row['permalink'].start_with?('brands/')
                   Spree::Taxonomy.find_by!(name: 'Brands')
                 else
                   categories_taxonomy
                 end

      taxon = Spree::Taxon.find_or_initialize_by(permalink: row['permalink'])
      taxon.taxonomy  = taxonomy
      taxon.name      = row['name']

      # Assign parent
      parent_permalink = row['parent_permalink'].presence
      if parent_permalink.present?
        parent = Spree::Taxon.find_by(permalink: parent_permalink)
        if parent
          taxon.parent = parent
        else
          # Fallback to taxonomy root
          taxon.parent = taxonomy.root
          Rails.logger.warn("[Seo::TaxonImporter] Parent not found: #{parent_permalink}, using taxonomy root")
        end
      else
        taxon.parent = taxonomy.root
      end

      taxon.meta_title       = row['meta_title'].presence
      taxon.meta_description = row['meta_description'].presence
      taxon.meta_keywords    = row['meta_keywords'].presence
      taxon.description      = row['description_html'].presence

      # Store rich description + batch_id in public_metadata for rollback
      taxon.public_metadata ||= {}
      taxon.public_metadata = taxon.public_metadata.merge(
        'seo_batch_id'       => @batch_id,
        'description_html'   => row['description_html'].presence
      )

      taxon
    end

    def attach_hero_image(taxon, filename)
      # Search in subdirectories of images/
      path = Dir.glob(IMAGES_DIR.join('**', filename)).first
      return unless path && File.exist?(path)
      return if taxon.image.attached? && taxon.image.blob.filename.to_s == filename

      taxon.image.attach(
        io:           File.open(path),
        filename:     filename,
        content_type: Marcel::MimeType.for(Pathname.new(path))
      )
    rescue => e
      Rails.logger.warn("[Seo::TaxonImporter] Image attach failed for #{filename}: #{e.message}")
    end
  end
end
