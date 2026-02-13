# frozen_string_literal: true

# Register Saferpay as an available payment method in Spree
Rails.application.config.after_initialize do
  Spree.payment_methods << Spree::Gateway::Saferpay unless Spree.payment_methods.include?(Spree::Gateway::Saferpay)
end

# Load the checkout controller decorator
require_relative '../../app/controllers/spree/checkout_controller_saferpay_decorator'
