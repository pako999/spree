# Remap Spree analytics event names to match Shopify's Klaviyo event names.
# This ensures existing Klaviyo flows (built for Shopify) fire correctly
# without needing to update triggers in the Klaviyo dashboard.
#
# Spree default         → Shopify equivalent
# ─────────────────────────────────────────────
# Order Completed       → Placed Order
# Product Viewed        → Viewed Product
# Product Added         → Added to Cart
# Checkout Started      → Started Checkout
# Product List Viewed   → Viewed Collection

Rails.application.config.after_initialize do
  Spree.analytics.events = Spree.analytics.events.merge(
    order_completed:      'Placed Order',
    product_viewed:       'Viewed Product',
    product_added:        'Added to Cart',
    product_removed:      'Removed from Cart',
    checkout_started:     'Started Checkout',
    product_list_viewed:  'Viewed Collection',
    product_searched:     'Submitted Search'
  )
end
