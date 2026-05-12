# Pin npm packages by running ./bin/importmap

pin "application"
pin "@hotwired/turbo-rails", to: "turbo.min.js"
pin "@hotwired/stimulus", to: "stimulus.min.js"
pin "@hotwired/stimulus-loading", to: "stimulus-loading.js"
pin_all_from "app/javascript/controllers", under: "controllers"

# Override spree_storefront's mobile_nav_controller with our patched version.
# The gem's compiled version has iOS Safari bugs (template inside button, innerHTML).
# This pin makes the importmap resolve the gem's module key to our local file.
pin "spree/storefront/controllers/mobile_nav_controller", to: "controllers/mobile_nav_controller.js"

# Override spree_storefront's checkout_summary_controller so the order
# summary is always expanded (never folded) during checkout.
pin "spree/storefront/controllers/checkout_summary_controller", to: "controllers/checkout_summary_controller.js"
