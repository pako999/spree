# Fix PostgreSQL / Mobility gem errors when sorting products by price.
#
# Two separate issues:
# 1. `order_by_price` uses GROUP BY + MIN(amount), which crashes
#    Mobility gem's `select_for_count` (undefined method 'right')
# 2. `execute` appends `.distinct` which conflicts with ORDER BY
#    on subquery/aggregate expressions (PG: ORDER BY must appear in select list)
#
# Solution: Use a subquery for price sorting AND skip .distinct when
# the sort already guarantees unique results through the subquery approach.
Rails.application.config.after_initialize do
  Spree::Products::Find.class_eval do
    private

    # Replace the problematic order_by_price method with a subquery approach
    def order_by_price(scope, sort_order)
      @price_sorted = true

      min_price_sql = <<~SQL.squish
        (SELECT MIN(p.amount)
         FROM spree_prices p
         JOIN spree_variants v ON v.id = p.variant_id AND v.deleted_at IS NULL
         WHERE v.product_id = spree_products.id
           AND p.deleted_at IS NULL
           AND p.currency = #{ActiveRecord::Base.connection.quote(currency)}
           AND p.amount IS NOT NULL)
      SQL

      scope.where("#{min_price_sql} IS NOT NULL")
           .select("spree_products.*, #{min_price_sql} AS min_price")
           .order(Arel.sql("min_price #{sort_order == :desc ? 'DESC' : 'ASC'}"))
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

      # When price-sorted, the subquery is in the SELECT list so DISTINCT works.
      # For GROUP BY sorts (taxon position), skip distinct as GROUP BY deduplicates.
      if products.values[:group].present?
        products
      else
        products.distinct
      end
    end
  end
end
