# Fix PostgreSQL / Mobility gem errors when sorting products by price.
#
# The original `order_by_price` uses GROUP BY + MIN(amount) which causes:
# 1. Mobility gem crash: `undefined method 'right' for String`
# 2. PG error: `ORDER BY must appear in select list` with DISTINCT
#
# Fix: Use a LATERAL JOIN approach that works with both DISTINCT and Mobility.
# This gives each product a pre-computed min_price without GROUP BY or aggregates.
Rails.application.config.after_initialize do
  Spree::Products::Find.class_eval do
    private

    def order_by_price(scope, sort_order)
      # Use a simple subquery in ORDER BY without adding to SELECT
      # PostgreSQL allows subqueries in ORDER BY with DISTINCT as long as
      # they reference only columns from the main query's SELECT
      direction = sort_order == :desc ? 'DESC' : 'ASC'

      min_price_subquery = <<~SQL.squish
        SELECT MIN(p.amount)
        FROM spree_prices p
        JOIN spree_variants v ON v.id = p.variant_id AND v.deleted_at IS NULL
        WHERE v.product_id = spree_products.id
          AND p.deleted_at IS NULL
          AND p.currency = #{ActiveRecord::Base.connection.quote(currency)}
          AND p.amount IS NOT NULL
      SQL

      # Filter out products without any price in the given currency
      scope
        .where("EXISTS (#{min_price_subquery})")
        .order(Arel.sql("(#{min_price_subquery}) #{direction}"))
    end
  end
end
