# frozen_string_literal: true

namespace :simprosys do
  desc "Sync all active products to Simprosys Google Feed API"
  task sync: :environment do
    puts "Starting Simprosys product sync..."
    service = SimprosysSyncService.new
    result = service.sync_all

    puts "\n=== Simprosys Sync Results ==="
    puts "Total products: #{result[:total]}"
    puts "Synced:         #{result[:synced]}"
    puts "Skipped:        #{result[:skipped]}"
    puts "Errors:         #{result[:errors].size}"

    if result[:errors].any?
      puts "\nErrors:"
      result[:errors].each do |err|
        puts "  - #{err.inspect}"
      end
    end
  end

  desc "Sync a single product to Simprosys by Spree product ID"
  task :sync_product, [:product_id] => :environment do |_t, args|
    product_id = args[:product_id]
    abort "Usage: rake simprosys:sync_product[PRODUCT_ID]" unless product_id

    puts "Syncing product #{product_id} to Simprosys..."
    service = SimprosysSyncService.new
    result = service.sync_product(product_id)

    if result[:status]
      puts "✅ Product synced successfully"
    else
      puts "❌ Sync failed: #{result[:message]}"
    end
  end

  desc "Test Simprosys API authentication"
  task test_auth: :environment do
    require "net/http"
    require "json"

    client_id = ENV.fetch("SIMPROSYS_CLIENT_ID")
    client_secret = ENV.fetch("SIMPROSYS_CLIENT_SECRET")

    uri = URI("https://api.simprosysapis.com/api/v1/token/")
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true

    request = Net::HTTP::Post.new(uri)
    request["Content-Type"] = "application/json"
    request.body = { client_id: client_id, client_secret: client_secret }.to_json

    response = http.request(request)
    parsed = JSON.parse(response.body)

    if parsed["status"]
      puts "✅ Authentication successful!"
      puts "   Access token: #{parsed.dig('data', 'access_token')&.first(20)}..."
      puts "   Shop ID: #{ENV['SIMPROSYS_SHOP_ID']}"
    else
      puts "❌ Authentication failed: #{parsed['message']}"
      puts "   Error code: #{parsed['error_code']}"
      if parsed["error_code"] == "1105"
        puts "\n   ⚠️  Your server IP is not whitelisted in Simprosys."
        puts "   Add this IP to your Simprosys app's authorized IPs:"
        # Try to detect IP
        begin
          ip = Net::HTTP.get(URI("https://api.ipify.org"))
          puts "   → #{ip}"
        rescue
          puts "   → (could not detect IP)"
        end
      end
    end
  end
end
