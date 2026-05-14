# frozen_string_literal: true

# Geo-IP locale and currency detection using Cloudflare's CF-IPCountry header.
# This runs before Spree's locale/currency resolution, but user/session/params
# selections always take priority (handled by Spree core).
module Spree
  module StoreControllerDecorator
    extend ActiveSupport::Concern

    COUNTRY_TO_LOCALE = {
      'DE' => 'de', 'AT' => 'de', 'CH' => 'de', 'LI' => 'de', 'LU' => 'de',
      'ES' => 'es',
      'SI' => 'sl-SI'
    }.freeze

    COUNTRY_TO_CURRENCY = {
      'CH' => 'CHF', 'LI' => 'CHF',
      'GB' => 'GBP',
      'SE' => 'SEK', 'DK' => 'SEK',
      'CZ' => 'CZK',
      'HU' => 'HUF',
      'AU' => 'AUD',
      'CA' => 'CAD',
      'US' => 'USD',
      'JP' => 'JPY',
      'NZ' => 'NZD',
      'AE' => 'AED',
      'BR' => 'BRL',
      'RU' => 'RUB'
    }.freeze

    prepended do
      before_action :set_geo_currency
    end

    # Eager-load associations used by the product card template.
    # master :images   — product card thumbnail (was N+1 per card!)
    # master/variants :stock_items — needed for purchasable? / in_stock? badges
    # variants :option_values — color swatches on product cards
    def storefront_products_includes
      {
        taxons: [:taxonomy],
        master: [:images, :prices, { stock_items: :stock_location }],
        variants: [
          :images,
          :prices,
          { stock_items: :stock_location },
          { option_values: :option_type }
        ],
        option_types: []
      }
    end

    # Override: push zero-stock products to bottom of category listings.
    # We let the parent build the full query, then wrap it to prepend stock sort.
    def storefront_products
      return @storefront_products if @storefront_products

      finder_params = default_products_finder_params
      finder_params[:sort_by] ||= @taxon&.sort_order || 'manual'

      products = storefront_products_finder
                   .new(scope: storefront_products_scope, params: finder_params)
                   .execute
                   .includes(storefront_products_includes)
                   .preload_associations_lazily

      # Push out-of-stock products to the bottom of listings.
      # Use a derived table JOIN instead of adding to SELECT to avoid
      # Mobility gem's count method crashing on custom SQL expressions.
      stock_join = <<~SQL.squish
        LEFT JOIN (
          SELECT DISTINCT sv.product_id
          FROM spree_stock_items ssi
          INNER JOIN spree_variants sv ON sv.id = ssi.variant_id
          WHERE sv.is_master = FALSE
            AND sv.deleted_at IS NULL
            AND (ssi.count_on_hand > 0 OR ssi.backorderable = TRUE)
        ) _in_stock ON _in_stock.product_id = spree_products.id
      SQL
      products = products.joins(stock_join)
                         .order(Arel.sql("CASE WHEN _in_stock.product_id IS NOT NULL THEN 0 ELSE 1 END ASC"))


      default_per_page = Spree::Storefront::Config[:products_per_page]
      per_page = params[:per_page].present? ? params[:per_page].to_i : default_per_page
      @storefront_products = paginate_collection(products, limit: per_page)
    end

    private

    def visitor_country
      request.headers['CF-IPCountry'].presence
    end

    # Disabled: geo-IP locale auto-detection was causing Googlebot (routed
    # through Vienna/SI by Cloudflare) to see lang="sl" on canonical English
    # pages (/products/...), making Google index them as Slovenian.
    # Locale is now set ONLY by the URL prefix (/de/..., /sl-SI/..., etc.).
    # Currency geo-detection (set_geo_currency) is unaffected.
    def config_locale
      nil
    end

    def set_geo_currency
      # Only auto-detect on first visit — once session[:currency] is set
      # (by user switching manually or by a previous geo-detection), don't override.
      return if session.key?(:currency)

      country = visitor_country
      return if country.blank?

      currency = COUNTRY_TO_CURRENCY[country]
      return unless currency && supported_currency?(currency)

      session[:currency] = currency
    end
  end
end

Spree::StoreController.prepend(Spree::StoreControllerDecorator)
Spree::StoreController.include(Spree::CacheableStorefront)
