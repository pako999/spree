# Set the host name for URL generation
SitemapGenerator::Sitemap.default_host = "https://www.surf-store.com"

# Store sitemaps in the public directory
SitemapGenerator::Sitemap.public_path = 'public/'

SitemapGenerator::Sitemap.create do
  # We use the Spree engine's route helpers
  spree = Spree::Core::Engine.routes.url_helpers

  # Fetch all supported locales from the default store
  begin
    store = Spree::Store.default
    locales = store.supported_locales_list
  rescue
    locales = ['en'] # Fallback
  end

  # Iterate through each locale to generate localized URLs
  locales.each do |locale|
    I18n.with_locale(locale) do
      # Add Homepage for this locale
      add spree.root_path(locale: locale), changefreq: 'daily', priority: 1.0

      # Add Products
      # We only index active, non-deleted products
      Spree::Product.active.find_each do |product|
        add spree.product_path(product, locale: locale), 
            lastmod: product.updated_at, 
            changefreq: 'daily', 
            priority: 0.8
      end

      # Add Taxons (Categories)
      # We exclude the root taxon (usually "Categories" or "Brands")
      Spree::Taxon.find_each do |taxon|
        next if taxon.root?
        add spree.nested_taxons_path(taxon, locale: locale), 
            lastmod: taxon.updated_at, 
            changefreq: 'weekly', 
            priority: 0.5
      end
    end
  end
end
