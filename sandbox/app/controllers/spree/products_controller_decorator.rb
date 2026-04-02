# frozen_string_literal: true

# Preload product associations for the product detail page to avoid N+1 queries.
# The base load_product only fetches the product record. With 49+ variants each
# requiring stock/price/option_value lookups, this causes 400+ individual queries.
module Spree
  module ProductsControllerDecorator
    private

    def load_product
      super

      return unless @product

      # Preload all variant associations needed by the product detail template,
      # variant picker, JSON-LD, and availability checks.
      ActiveRecord::Associations::Preloader.new(
        records: [@product],
        associations: {
          taxons: [:taxonomy],
          master: [:images, :prices, :stock_locations, { stock_items: :stock_location }],
          variants: [:images, :prices, :option_values, :stock_locations, { stock_items: :stock_location }],
          option_types: []
        }
      ).call
    end
  end
end

Spree::ProductsController.prepend(Spree::ProductsControllerDecorator)
