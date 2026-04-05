# frozen_string_literal: true
# SEO Import System — surf-store.com programmatic SEO
# Manages 12-week, 1000-page generation campaign across 8 batches.
#
# Usage:
#   rake seo:import_all
#   rake "seo:import_batch[batch_01_brands]"
#   rake "seo:validate[batch_01_brands]"
#   rake "seo:rollback[batch_01_brands]"
#   rake seo:generate_sitemap
#   rake "seo:generate_content[batch_01_brands]"

namespace :seo do
  BATCH_DIRS = Dir.glob(Rails.root.join('db/seo_data/batch_*')).map { |d| File.basename(d) }.sort.freeze

  # ── Import all batches ──────────────────────────────────────────────────────
  desc 'Import all SEO batches from db/seo_data/'
  task import_all: :environment do
    BATCH_DIRS.each do |batch|
      Rake::Task['seo:import_batch'].reenable
      Rake::Task['seo:import_batch'].invoke(batch)
    end
  end

  # ── Import one batch ────────────────────────────────────────────────────────
  desc 'Import one SEO batch — rake "seo:import_batch[batch_01_brands]"'
  task :import_batch, [:batch_name] => :environment do |_, args|
    batch = args[:batch_name].presence || abort('Provide batch_name')
    dir   = Rails.root.join('db/seo_data', batch)
    abort "Batch directory not found: #{dir}" unless File.directory?(dir)

    puts "\n══ Importing #{batch} ══"

    taxons_csv = dir.join('taxons.csv')
    if taxons_csv.exist?
      result = Seo::TaxonImporter.new(taxons_csv.to_s, batch_id: batch).import
      puts "  Taxons  — created:#{result[:created]} updated:#{result[:updated]} errors:#{result[:errors]}"
    end

    posts_csv = dir.join('posts.csv')
    if posts_csv.exist?
      result = Seo::PostImporter.new(posts_csv.to_s, batch_id: batch).import
      puts "  Posts   — created:#{result[:created]} updated:#{result[:updated]} errors:#{result[:errors]}"
    end

    puts "  Done."
  end

  # ── Validate (dry-run) ──────────────────────────────────────────────────────
  desc 'Dry-run CSV validation — rake "seo:validate[batch_01_brands]"'
  task :validate, [:batch_name] => :environment do |_, args|
    batch = args[:batch_name].presence || abort('Provide batch_name')
    dir   = Rails.root.join('db/seo_data', batch)
    abort "Batch directory not found: #{dir}" unless File.directory?(dir)

    errors = []
    warnings = []

    taxons_csv = dir.join('taxons.csv')
    if taxons_csv.exist?
      puts "\nValidating taxons.csv…"
      rows = CSV.read(taxons_csv.to_s, headers: true, encoding: 'UTF-8')
      required = %w[permalink name parent_permalink depth batch_id]
      missing_headers = required - rows.headers.compact
      errors << "taxons.csv missing headers: #{missing_headers.join(', ')}" if missing_headers.any?

      rows.each_with_index do |row, i|
        line = i + 2
        errors << "taxons.csv line #{line}: permalink blank" if row['permalink'].blank?
        errors << "taxons.csv line #{line}: name blank" if row['name'].blank?
        errors << "taxons.csv line #{line}: batch_id mismatch (#{row['batch_id']} != #{batch})" if row['batch_id'] != batch

        if row['meta_title'].present? && row['meta_title'].length > 60
          warnings << "taxons.csv line #{line}: meta_title too long (#{row['meta_title'].length} > 60): #{row['meta_title'].truncate(40)}"
        end
        if row['meta_description'].present? && row['meta_description'].length > 155
          warnings << "taxons.csv line #{line}: meta_description too long (#{row['meta_description'].length} > 155)"
        end
      end
      puts "  #{rows.count} rows"
    end

    posts_csv = dir.join('posts.csv')
    if posts_csv.exist?
      puts "\nValidating posts.csv…"
      rows = CSV.read(posts_csv.to_s, headers: true, encoding: 'UTF-8')
      required = %w[slug title category_slug batch_id]
      missing_headers = required - rows.headers.compact
      errors << "posts.csv missing headers: #{missing_headers.join(', ')}" if missing_headers.any?

      rows.each_with_index do |row, i|
        line = i + 2
        errors << "posts.csv line #{line}: slug blank" if row['slug'].blank?
        errors << "posts.csv line #{line}: title blank" if row['title'].blank?

        if row['meta_title'].present? && row['meta_title'].length > 60
          warnings << "posts.csv line #{line}: meta_title too long (#{row['meta_title'].length} > 60)"
        end
        if row['meta_description'].present? && row['meta_description'].length > 155
          warnings << "posts.csv line #{line}: meta_description too long (#{row['meta_description'].length} > 155)"
        end
      end
      puts "  #{rows.count} rows"
    end

    if warnings.any?
      puts "\n⚠  Warnings (#{warnings.size}):"
      warnings.each { |w| puts "  #{w}" }
    end

    if errors.any?
      puts "\n✗  Errors (#{errors.size}):"
      errors.each { |e| puts "  #{e}" }
      exit 1
    else
      puts "\n✓  Validation passed#{warnings.any? ? ' with warnings' : ''}"
    end
  end

  # ── Rollback ────────────────────────────────────────────────────────────────
  desc 'Delete all records created by a batch — rake "seo:rollback[batch_01_brands]"'
  task :rollback, [:batch_name] => :environment do |_, args|
    batch = args[:batch_name].presence || abort('Provide batch_name')

    puts "\nRolling back #{batch}…"

    # Delete taxons with this batch_id in public_metadata
    taxon_count = 0
    Spree::Taxon.where("public_metadata->>'seo_batch_id' = ?", batch).each do |t|
      t.destroy
      taxon_count += 1
    end

    # Delete posts with this batch_id in metafield
    post_count = 0
    Spree::Post.joins(:public_metafields)
               .where(spree_metafields: { key: 'seo_batch_id', value: batch })
               .each do |p|
      p.destroy
      post_count += 1
    end

    puts "  Deleted #{taxon_count} taxons, #{post_count} posts"
  end

  # ── Generate sitemap ────────────────────────────────────────────────────────
  desc 'Write public/sitemap-seo.xml for all SEO taxons and posts'
  task generate_sitemap: :environment do
    store    = Spree::Store.find(2)
    base_url = "https://#{store.url}"
    path     = Rails.root.join('public/sitemap-seo.xml')

    urls = []

    # Taxons with seo_batch_id
    Spree::Taxon.where("public_metadata ? 'seo_batch_id'").each do |t|
      urls << {
        loc:     "#{base_url}/#{I18n.locale}/t/#{t.permalink}",
        lastmod: t.updated_at.iso8601,
        changefreq: 'weekly',
        priority: '0.7'
      }
    end

    # Posts with seo_batch_id metafield
    Spree::Post.published
               .joins(:public_metafields)
               .where(spree_metafields: { key: 'seo_batch_id' })
               .each do |p|
      urls << {
        loc:     "#{base_url}/#{I18n.locale}/posts/#{p.slug}",
        lastmod: p.updated_at.iso8601,
        changefreq: 'monthly',
        priority: '0.6'
      }
    end

    xml = <<~XML
      <?xml version="1.0" encoding="UTF-8"?>
      <urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
      #{urls.map { |u| "  <url>\n    <loc>#{u[:loc]}</loc>\n    <lastmod>#{u[:lastmod]}</lastmod>\n    <changefreq>#{u[:changefreq]}</changefreq>\n    <priority>#{u[:priority]}</priority>\n  </url>" }.join("\n")}
      </urlset>
    XML

    File.write(path, xml)
    puts "Written #{urls.size} URLs to #{path}"
  end

  # ── Generate content via Claude API ─────────────────────────────────────────
  desc 'Generate content for a batch using Claude API — rake "seo:generate_content[batch_01_brands]"'
  task :generate_content, [:batch_name] => :environment do |_, args|
    batch = args[:batch_name].presence || abort('Provide batch_name')
    dir   = Rails.root.join('db/seo_data', batch)
    abort "Batch directory not found: #{dir}" unless File.directory?(dir)

    taxons_csv = dir.join('taxons.csv')
    abort "No taxons.csv found in #{batch}" unless taxons_csv.exist?

    rows = CSV.read(taxons_csv.to_s, headers: true, encoding: 'UTF-8')
    generator = Seo::ContentGenerator.new

    rows.each_with_index do |row, i|
      next if row['description_html'].present?

      puts "[#{i + 1}/#{rows.count}] Generating content for #{row['permalink']}…"

      result = generator.generate(
        keyword:   row['meta_keywords']&.split(',')&.first || row['name'],
        template:  'brand_category',
        variables: { name: row['name'], permalink: row['permalink'] }
      )

      row['description_html']  = result[:body_html]
      row['meta_title']        = result[:meta_title] if row['meta_title'].blank?
      row['meta_description']  = result[:meta_description] if row['meta_description'].blank?

      # Rate limit: 10 req/min
      sleep(6) if (i + 1) % 10 == 0
    end

    # Write back
    CSV.open(taxons_csv.to_s, 'w') do |csv|
      csv << rows.headers
      rows.each { |row| csv << row }
    end
    puts "Content generation complete — #{taxons_csv}"
  end
end
