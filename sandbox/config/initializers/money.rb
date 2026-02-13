# Configure EUR currency formatting: symbol after the amount (e.g., "3,299.00 €")
# Uses the Spree::Money default_formatting_rules which get merged into every
# Money#format call via the money gem.

Rails.application.config.after_initialize do
  Spree::Money.default_formatting_rules = {
    sign_before_symbol: true,
    symbol_position: :after
  }
end
