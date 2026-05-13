module Spree
  module ProductDecorator
    def self.prepended(base)
      base.ransack_alias :master_price, :master_default_price_amount

      base.whitelisted_ransackable_attributes ||= []
      base.whitelisted_ransackable_attributes << 'master_price'

      base.whitelisted_ransackable_associations ||= []
      base.whitelisted_ransackable_associations << 'master'

      # Override multi_search to support multi-word queries.
      # "harness kite" will match products containing BOTH "harness" AND "kite"
      # anywhere in the name or SKU, regardless of word order.
      base.scope :multi_search, lambda { |query, _include_options = false|
        return none if query.blank?

        words = query.to_s.strip.split(/\s+/).reject(&:blank?)
        return none if words.empty?

        # For each word, find matching product IDs from name or SKU
        matching_ids = nil
        words.each do |word|
          sanitized = ActiveRecord::Base.sanitize_sql_like(word.downcase)
          pattern = "%#{sanitized}%"

          name_matches = Spree::Product.where("LOWER(spree_products.name) LIKE ?", pattern).ids
          sku_matches  = Spree::Variant.where("LOWER(sku) LIKE ?", pattern).pluck(:product_id)
          word_ids = (name_matches + sku_matches).uniq

          matching_ids = matching_ids ? (matching_ids & word_ids) : word_ids
        end

        where(id: matching_ids || [])
      }
    end
  end
end

Spree::Product.prepend Spree::ProductDecorator
