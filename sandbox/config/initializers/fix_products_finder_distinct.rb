# Fix PostgreSQL / Mobility gem errors when sorting products by price.
#
# The original `order_by_price` uses GROUP BY + MIN(amount) which causes:
# 1. Mobility gem crash on `.count` (undefined method 'right' for String)
# 2. PG error with DISTINCT + ORDER BY on aggregate expressions
#
# Fix: Use a derived table JOIN that exposes min_price as a sortable column
# without adding it to SELECT (which breaks Mobility's count method).
Rails.application.config.after_initialize do
  Spree::Products::Find.class_eval do
    private

    def order_by_price(scope, sort_order)
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
  end
end
