# Fix PostgreSQL / Mobility gem errors when sorting products by price.
#
# Root cause: `with_currency` scope (called by `active(currency)`) adds
# `.distinct` which conflicts with ORDER BY on derived table columns.
# Additionally, the Finder's `execute` also appends `.distinct`.
#
# Fix: Use derived table JOIN for price sorting and remove DISTINCT from
# the query (the derived table JOIN guarantees one row per product anyway).
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

      # Remove DISTINCT that was added by with_currency scope —
      # the derived table JOIN already ensures one row per product
      scope.except(:distinct)
           .joins(price_join)
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

      # Skip .distinct for price-sorted queries — the derived table JOIN
      # already deduplicates and PG doesn't allow DISTINCT + ORDER BY
      # on non-SELECT columns
      @_price_sorted ? products : products.distinct
    end
  end
end
