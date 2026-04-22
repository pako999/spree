# frozen_string_literal: true
# Seo::BatchGenerator — reads a batch config.json, generates content via Claude API,
# and writes the results to taxons.csv or posts.csv ready for import.
#
# config.json format:
#   { "entity_type": "taxons"|"posts", "rows": [{ "keyword": "...", "template": "...", ... }] }
#
# Usage:
#   rake "seo:generate_content[batch_01_brands]"
#   # or directly:
#   Seo::BatchGenerator.new('batch_01_brands').run

require 'json'
require 'csv'

module Seo
  class BatchGenerator
    BATCH_ROOT = Rails.root.join('db', 'seo_data')

    def initialize(batch_name)
      @batch_name  = batch_name
      @config_path = BATCH_ROOT.join(batch_name, 'config.json')
      @generator   = ContentGenerator.new
    end

    def run
      raise "No config.json in #{@batch_name}" unless File.exist?(@config_path)

      config      = JSON.parse(File.read(@config_path))
      entity_type = config['entity_type']
      rows        = config['rows']

      output = rows.map.with_index do |row, i|
        sleep(6) if i > 0 && i % 10 == 0
        puts "[#{i + 1}/#{rows.length}] Generating: #{row['keyword']}"

        content = @generator.generate(
          template:  row['template'],
          keyword:   row['keyword'],
          variables: row.transform_keys(&:to_sym)
        )

        row.merge(
          'meta_title'       => content[:meta_title],
          'meta_description' => content[:meta_description],
          'body_html'        => content[:body_html],
          'description_html' => content[:body_html],
          'excerpt'          => content[:excerpt],
          'batch_id'         => @batch_name
        )
      end

      write_csv(entity_type, output)
      puts "\nGenerated #{output.length} rows → #{entity_type}.csv"
    end

    private

    def write_csv(entity_type, rows)
      path    = BATCH_ROOT.join(@batch_name, "#{entity_type}.csv")
      headers = entity_type == 'taxons' ? taxon_headers : post_headers

      CSV.open(path.to_s, 'w') do |csv|
        csv << headers
        rows.each { |r| csv << headers.map { |h| r[h] } }
      end
    end

    def taxon_headers
      %w[permalink name parent_permalink depth meta_title meta_description
         meta_keywords description_html hero_image_filename icon_filename batch_id]
    end

    def post_headers
      %w[slug title meta_title meta_description meta_keywords category_slug
         published_at excerpt body_html hero_image_filename schema_type
         related_taxon_permalinks related_product_skus batch_id]
    end
  end
end
