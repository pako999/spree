# Fix PostgreSQL / Mobility gem errors when sorting products by price.
#
# Problem: The `order_by_price` method adds MIN(price) to SELECT and GROUP BY,
# which conflicts with:
# 1. `.distinct` appended by `execute` (PG: ORDER BY must appear in select list)
# 2. Mobility gem's `select_for_count` which can't handle MIN() aggregates
#
# Solution: Use a subquery approach for price sorting that avoids
# adding aggregates to the main SELECT clause.
Rails.application.config.after_initialize do
  Spree::Products::Find.class_eval do
    private

    # Replace the problematic order_by_price method with a subquery approach
    def order_by_price(scope, sort_order)
      # Use a subquery to get min price per product, avoiding GROUP BY in the main query
      min_price_sql = <<~SQL
        (SELECT MIN(p.amount)
         FROM spree_prices p
         JOIN spree_variants v ON v.id = p.variant_id AND v.deleted_at IS NULL
         WHERE v.product_id = spree_products.id
           AND p.deleted_at IS NULL
           AND p.currency = #{ActiveRecord::Base.connection.quote(currency)}
           AND p.amount IS NOT NULL)
      SQL

      scope.where("#{min_price_sql.strip} IS NOT NULL")
           .order(Arel.sql("#{min_price_sql.strip} #{sort_order == :desc ? 'DESC' : 'ASC'}"))
    end
  end
end
