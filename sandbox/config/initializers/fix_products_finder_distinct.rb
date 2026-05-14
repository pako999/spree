# Fix PostgreSQL / Mobility gem errors when sorting products by price.
#
# Issues:
# 1. PG: ORDER BY expressions must appear in select list (with DISTINCT)
# 2. Mobility gem: undefined method 'right' for String (when .count is called
#    with custom SQL in SELECT)
#
# Fix: Use derived table JOIN + add min_price to SELECT (fixes #1),
# and skip .distinct for price-sorted queries since the derived table JOIN
# already ensures one row per product (fixes both #1 and #2).
Rails.application.config.after_initialize do
  Spree::Products::Find.class_eval do
    private

    def order_by_price(scope, sort_order)
      @_price_sorted = true
      direction = sort_order == :desc ? 'DESC' : 'ASC'
      quoted_currency = ActiveRecord::Base.connection.quote(currency)

      price_join = <<~SQL.squish
        INNER JOIN (
          SELECT v.product_id, MIN(pr.amount) AS min_price
          FROM spree_variants v
          JOIN spree_prices pr ON pr.variant_id = v.id AND pr.deleted_at IS NULL
          WHERE v.deleted_at IS NULL
            AND pr.currency = #{quoted_currency}
            AND pr.amount IS NOT NULL
          GROUP BY v.product_id
        ) _price_sort ON _price_sort.product_id = spree_products.id
      SQL

      scope.joins(price_join)
           .order(Arel.sql("_price_sort.min_price #{direction}"))
    end

    public

    def execute
      products = by_ids(scope)
      products = by_skus(products)
      products = by_query(products)
      products = include_discontinued(products)
      products = by_price(products)
      products = by_currency(products)
      products = by_taxons(products)
      products = by_concat_taxons(products)
      products = by_name(products)
      products = by_slug(products)
      products = by_options(products)
      products = by_option_value_ids(products)
      products = by_properties(products)
      products = by_tags(products)
      products = include_deleted(products)
      products = show_only_stock(products)
      products = show_only_backorderable(products)
      products = show_only_purchasable(products)
      products = show_only_out_of_stock(products)
      products = by_taxonomies(products)
      products = by_vendor_ids(products) if respond_to?(:by_vendor_ids, true)
      products = ordered(products)

      # Skip .distinct for price-sorted queries:
      # - The derived table JOIN already ensures one row per product
      # - DISTINCT conflicts with ORDER BY on derived table columns in PG
      # - Mobility gem can't handle .count on queries with custom SQL in SELECT
      if @_price_sorted
        products
      else
        products.distinct
      end
    end
  end
end
