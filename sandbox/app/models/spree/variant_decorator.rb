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

# Fix: when the admin form submits stock_items_attributes without an ID
# (e.g. after Turbo frame refresh during image upload), resolve the existing
# stock item by (variant_id, stock_location_id) instead of trying to create a new one.
module Spree
  module StockItemIdResolver
    def stock_items_attributes=(attrs)
      resolved = case attrs
                 when Hash
                   attrs.transform_values { |item| resolve_stock_item_attrs(item) }
                 when Array
                   attrs.map { |item| resolve_stock_item_attrs(item) }
                 else
                   attrs
                 end
      super(resolved)
    end

    private

    def resolve_stock_item_attrs(item_attrs)
      return item_attrs if item_attrs['id'].present? || item_attrs[:id].present?

      loc_id = item_attrs['stock_location_id'] || item_attrs[:stock_location_id]
      return item_attrs unless loc_id.present?

      existing = stock_items.find_by(stock_location_id: loc_id.to_s)
      return item_attrs unless existing

      item_attrs.is_a?(HashWithIndifferentAccess) ? item_attrs.merge('id' => existing.id.to_s) : item_attrs.to_h.merge('id' => existing.id.to_s)
    end
  end
end

Spree::Variant.prepend(Spree::StockItemIdResolver)
