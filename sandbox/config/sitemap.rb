# Set the host name for URL generation
SitemapGenerator::Sitemap.default_host = "https://www.surf-store.com"
SitemapGenerator::Sitemap.sitemaps_host = "https://www.surf-store.com"
SitemapGenerator::Sitemap.compress      = false

SitemapGenerator::Sitemap.create do
  spree = Spree::Core::Engine.routes.url_helpers

  # Policy / static pages — deduplicate by slug
  Spree::Policy.find_each do |policy|
    next if policy.slug.blank?
    add "/policies/#{policy.slug}", changefreq: 'monthly', priority: 0.6
  end

  # Products — default (English) locale only, no locale prefix
  I18n.with_locale(:en) do
    Spree::Product.active.find_each do |product|
      add spree.product_path(product),
          lastmod: product.updated_at,
          changefreq: 'daily',
          priority: 0.8
    end

    # Categories and brand taxons — exclude root, tags, and homepage taxon
    seen_paths = Set.new
    Spree::Taxon.includes(:taxonomy).find_each do |taxon|
      next if taxon.root?
      next if taxon.taxonomy&.name&.downcase == 'tags'
      path = spree.nested_taxons_path(taxon)
      next if seen_paths.include?(path)
      seen_paths << path
      add path,
          lastmod: taxon.updated_at,
          changefreq: 'weekly',
          priority: 0.7
    end

    # Blog posts
    Spree::Post.where.not(published_at: nil).find_each do |post|
      add spree.post_path(post),
          lastmod: post.updated_at,
          changefreq: 'monthly',
          priority: 0.6
    end
  end
end
