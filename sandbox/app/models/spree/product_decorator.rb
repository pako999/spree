module Spree
  module ProductDecorator
    def self.prepended(base)
      base.ransack_alias :master_price, :master_default_price_amount

      base.whitelisted_ransackable_attributes ||= []
      base.whitelisted_ransackable_attributes << 'master_price'

      base.whitelisted_ransackable_associations ||= []
      base.whitelisted_ransackable_associations << 'master'
    end
  end
end

Spree::Product.prepend Spree::ProductDecorator
