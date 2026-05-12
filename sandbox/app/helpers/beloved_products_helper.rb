module BelovedProductsHelper
  def beloved_products_for_today(limit: 8)
    seed = Date.today.yday
    rng  = Random.new(seed)

    pool = Rails.cache.fetch("beloved_products/pool/#{Date.today}", expires_in: 4.hours) do
      current_store.products
        .where("spree_products.name ILIKE ?", "%2026%")
        .available
        .joins(:variants_including_master)
        .where(spree_variants: { is_master: false, deleted_at: nil })
        .where("EXISTS (SELECT 1 FROM spree_stock_items si WHERE si.variant_id = spree_variants.id AND (si.count_on_hand > 0 OR si.backorderable = TRUE))")
        .includes(:taxons, master: [:prices, :images])
        .distinct
        .limit(300)
        .to_a
    end

    pool.shuffle!(random: rng)

    seen_cats = Set.new
    result    = []
    leftover  = []

    pool.each do |product|
      top_cat = product.taxons.find { |t| t.permalink.start_with?("categories/") && t.depth == 1 }
      cat_key = top_cat&.id
      if cat_key.nil? || !seen_cats.include?(cat_key)
        result << product
        seen_cats.add(cat_key)
      else
        leftover << product
      end
      break if result.size >= limit
    end

    result.concat(leftover.first(limit - result.size)) if result.size < limit
    result.first(limit)
  end
end
