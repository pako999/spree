# Fix PostgreSQL error: "for SELECT DISTINCT, ORDER BY expressions must
# appear in select list"
#
# The Products::Find#execute method appends .distinct at the end,
# which conflicts with GROUP BY queries (price sort, taxon position sort).
# GROUP BY already deduplicates, so DISTINCT is redundant and causes errors.
#
# This patch removes .distinct when the query already has GROUP BY values.
Rails.application.config.after_initialize do
  Spree::Products::Find.class_eval do
    private

    alias_method :original_ordered, :ordered

    def ordered(products)
      result = original_ordered(products)
      # Mark that we used a GROUP BY ordering so execute can skip .distinct
      @uses_group_by = result.values[:group].present?
      result
    end

    # Override execute to conditionally skip .distinct
    define_method(:execute_without_fix) { nil } # placeholder

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

      # Skip .distinct when the query already has GROUP BY (e.g. price sort)
      # GROUP BY already deduplicates rows; adding DISTINCT causes PG errors
      if @uses_group_by
        products
      else
        products.distinct
      end
    end
  end
end
