# frozen_string_literal: true

# Register Saferpay as an available payment method in Spree
Rails.application.config.after_initialize do
  Spree.payment_methods << Spree::Gateway::Saferpay unless Spree.payment_methods.include?(Spree::Gateway::Saferpay)
end

# Load the checkout controller decorator after all classes are loaded
Rails.application.config.to_prepare do
  if defined?(Spree::CheckoutController)
    Spree::CheckoutController.prepend(Spree::CheckoutControllerSaferpayDecorator)
  end
end
