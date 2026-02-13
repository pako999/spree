# fix_store.rb
puts "--- FIXING STORE ---"

# 1. Wipe all existing store data (bypassing validation errors)
Spree::Store.delete_all
puts "Old store data wiped."

# 2. Create a brand new, clean store record
store = Spree::Store.new
store.code = 'kite-shop-vps'
store.name = 'Kite Shop'
store.url = '51.195.110.240'
store.mail_from_address = 'store@51.195.110.240'
store.default_currency = 'USD'
store.default = true

# 3. Save it
if store.save
  puts "--- SUCCESS ---"
  puts "New Store created! URL is: #{store.url}"
else
  puts "Error creating store: #{store.errors.full_messages.join(', ')}"
end

# 4. Clear cache to ensure app sees the change
Rails.cache.clear
