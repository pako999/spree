# frozen_string_literal: true

# Run with: RAILS_ENV=production rails runner sandbox/db/seeds/add_saferpay_payment_method.rb

puts "Creating Saferpay payment method..."

saferpay = Spree::Gateway::Saferpay.find_or_initialize_by(name: 'Saferpay')
saferpay.assign_attributes(
  active: true,
  display_on: 'both',
  auto_capture: false,
  preferred_customer_id: '283078',
  preferred_terminal_id: '17777090',
  preferred_api_username: 'API_283078_23118052',
  preferred_api_password: '4zb_.#sSV7)5=|zX',
  preferred_test_mode: true
)
saferpay.save!

# Associate with all stores
Spree::Store.all.each do |store|
  unless store.payment_methods.include?(saferpay)
    store.payment_methods << saferpay
    puts "  Associated Saferpay with store: #{store.name}"
  end
end

puts "Saferpay payment method created successfully! (ID: #{saferpay.id})"
