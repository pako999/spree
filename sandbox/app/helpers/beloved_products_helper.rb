module BelovedProductsHelper
  # Returns a diverse, daily-rotating set of 2026 in-stock products.
  # - Picks one product per top-level category first (diversity)
  # - Shuffles with today's date as random seed (daily rotation)
  # - Falls back to any remaining 2026 products to fill the limit
  #
  # @param limit [Integer] number of products to return
  # @return [Array<Spree::Product>]
  def beloved_products_for_today(limit: 8)
    seed = Date.today.yday  # 1-365, changes daily
    rng  = Random.new(seed)

    # --- 1. Fetch a pool of 2026 in-stock products (with all display associations) ---
    pool = Rails.cache.fetch("beloved_products/pool/#{Date.today}", expires_in: 4.hours) do
      current_store.products
        .where("spree_products.name ILIKE ?", "%2026%")
        .available
        .joins(:variants_including_master)
        .where(spree_variants: { is_master: false, deleted_at: nil })
        .where(
          "EXISTS (
            SELECT 1 FROM spree_stock_items si
            WHERE si.variant_id = spree_variants.id
              AND (si.count_on_hand > 0 OR si.backorderable = true)
          )"
        )
        .includes(:taxons, :images,
                  master: [:prices, :images, { stock_items: :stock_location }])
        .distinct
        .limit(300)
        .to_a
    end

    pool.shuffle!(random: rng)

    # --- 2. Pick one per top-level category for diversity ---
    seen_cats = Set.new
    result    = []
    leftover  = []

    pool.each do |product|
      top_cat = product.taxons.find { |t| t.permalink.start_with?('categories/') && t.depth == 1 }
      cat_key = top_cat&.id

      if cat_key.nil? || !seen_cats.include?(cat_key)
        result << product
        seen_cats.add(cat_key)
      else
        leftover << product
      end

      break if result.size >= limit
    end

    # --- 3. Fill remaining slots if we didn't get enough categories ---
    if result.size < limit
      result.concat(leftover.first(limit - result.size))
    end

    result.first(limit)
  end
end
