# frozen_string_literal: true

# Override product name search to always query spree_products.name directly.
# Products store names in the name column, not in spree_product_translations.
# The default implementation uses join_translation_table when use_translations?
# returns true (non-default locale), joining on locale='sl-SI' and finding nothing.
module Spree
  module VariantDecorator
    extend ActiveSupport::Concern

    included do
      singleton_class.prepend(ClassMethods)
    end

    module ClassMethods
      def product_name_or_sku_cont(query)
        sanitized_query = ActiveRecord::Base.sanitize_sql_like(query.to_s.downcase.strip)
        query_pattern = "%#{sanitized_query}%"
        sku_condition = arel_table[:sku].lower.matches(query_pattern)
        product_name_condition = Product.arel_table[:name].lower.matches(query_pattern)
        joins(:product).where(product_name_condition.or(sku_condition))
      end
    end
  end

  # Separate prepend module for instance method overrides.
  # When stock_items are preloaded, skip the Rails.cache round-trip for
  # backorderable? — quantifier.backorderable? uses in-memory stock_items.
  #
  # Also fix in_stock?: core requires BOTH stock_items AND stock_locations
  # to be marked loaded, but we preload via `{ stock_items: :stock_location }`
  # which loads each stock_item's stock_location but does NOT mark the
  # through-association :stock_locations as loaded. We only need stock_items.
  module VariantBackorderableDecorator
    def backorderable?
      if association(:stock_items).loaded?
        @backorderable ||= quantifier.backorderable?
      else
        super
      end
    end

    def in_stock?
      @in_stock ||= if association(:stock_items).loaded?
                      total_on_hand.positive?
                    else
                      Rails.cache.fetch(in_stock_cache_key, version: cache_version) do
                        total_on_hand.positive?
                      end
                    end
    end
  end
end

Spree::Variant.include(Spree::VariantDecorator)
Spree::Variant.prepend(Spree::VariantBackorderableDecorator)
