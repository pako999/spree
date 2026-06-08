# frozen_string_literal: true

# Decorator for Spree's products finder.
#
# Fixes duplicate-product rows on category pages.
#
# Spree's stock by_taxons does:
#   products.joins(:classifications).where(taxon_id: <ids>)
# A product belonging to multiple taxons that all match the filter (e.g.
# /t/categories/kitesurfing/kiteboards descendants + a brand sub-taxon)
# produces multiple JOIN rows. Spree appends .distinct at the end of execute,
# but the storefront then chains .includes(storefront_products_includes) and
# Rails eager-loads can re-introduce duplicates in the iterator.
#
# Subquery filter (WHERE id IN (SELECT product_id FROM classifications WHERE
# taxon_id IN (...))) returns one row per product by construction and is
# immune to later JOIN re-duplication.
module Spree
  module Products
    module FindDecorator
      private

      def by_taxons(products)
        return products unless taxons?

        products.where(
          id: Spree::Classification
                .where(taxon_id: taxons)
                .select(:product_id)
        )
      end
    end
  end
end

Spree::Products::Find.prepend Spree::Products::FindDecorator
