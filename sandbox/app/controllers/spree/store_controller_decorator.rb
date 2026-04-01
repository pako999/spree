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

    included do
      before_action :set_geo_currency
    end

    private

    def visitor_country
      request.headers['CF-IPCountry'].presence
    end

    # Called by Spree::Core::ControllerHelpers::Locale as a fallback
    def config_locale
      country = visitor_country
      return nil if country.blank?

      locale = COUNTRY_TO_LOCALE[country]
      return nil unless locale && supported_locale?(locale)

      locale
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

Spree::StoreController.include(Spree::StoreControllerDecorator)
