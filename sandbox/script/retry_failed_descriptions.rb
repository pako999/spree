# frozen_string_literal: true
# Retry fetching descriptions for products that still have a link-based description
# Run: bin/kamal app exec --reuse "bin/rails runner /rails/script/retry_failed_descriptions.rb"

require 'net/http'
require 'uri'

def fetch_description(url)
  return nil if url.blank?
  uri = URI.parse(url)
  tries = 0
  loop do
    tries += 1
    return nil if tries > 3
    res = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == 'https', open_timeout: 15, read_timeout: 30) do |http|
      http.request(Net::HTTP::Get.new(uri))
    end
    case res
    when Net::HTTPSuccess
      html = res.body.to_s.force_encoding('UTF-8').encode('UTF-8', invalid: :replace, undef: :replace)
      html.gsub!(/<meta[^>]*>/i, '')
      html.gsub!(/<script[^>]*>.*?<\/script>/mi, '')
      html.gsub!(/<style[^>]*>.*?<\/style>/mi, '')
      return html.strip.presence
    when Net::HTTPRedirection
      uri = URI.parse(res['location'])
    else
      return nil
    end
  end
rescue => e
  puts "  [fetch err: #{e.message.truncate(60)}]"
  nil
end

products = Spree::Product.where("description LIKE ?", "%cdn.gaastra.io%href%")
puts "Products with link-based description: #{products.count}"

fixed  = 0
failed = 0

products.each do |product|
  url = product.description.to_s.match(/href="([^"]+)"/)&.[](1)
  unless url
    puts "#{product.name}: could not parse URL"
    next
  end

  print "#{product.name} ..."
  html = fetch_description(url)
  if html
    product.update_column(:description, html)
    fixed += 1
    puts " ✓"
  else
    failed += 1
    puts " ✗ (#{url.truncate(60)})"
  end
end

puts "\nDone. Fixed: #{fixed}, Failed: #{failed}"
