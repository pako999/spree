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
