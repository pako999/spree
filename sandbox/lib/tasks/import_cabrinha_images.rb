#!/usr/bin/env ruby
# frozen_string_literal: true
# Cabrinha image importer - uses non-standard column names:
#   EAN/UPC instead of Variant Barcode
#   Image direct link 1-6 for product images (no variant-specific images)
#
# Run: bundle exec rails runner /rails/tmp/import_cabrinha_images.rb

require 'csv'
require 'net/http'

SHEET_URL = 'https://docs.google.com/spreadsheets/d/1nk-NW2QXQo6uTGr00AJ2q62svZS_q3muS7_SKQVZc_s/export?format=csv'

puts "=== Cabrinha Images ==="
puts "Downloading CSV..."

require 'open-uri'
csv_data = URI.open(SHEET_URL, "User-Agent" => "Mozilla/5.0", read_timeout: 60).read
puts "  #{csv_data.lines.count} rows"

# Build variant lookup by barcode
variants_by_barcode = {}
Spree::Variant.where.not(barcode: [nil, ""]).find_each do |v|
  bc = v.barcode.to_s.strip
  next if bc.blank?
  existing = variants_by_barcode[bc]
  variants_by_barcode[bc] = v if existing.nil? || existing.is_master?
end
puts "  #{variants_by_barcode.size} variants indexed"

def fetch_image(url)
  uri = URI.parse(url)
  response = Net::HTTP.start(uri.host, uri.port,
    use_ssl: uri.scheme == 'https',
    open_timeout: 15, read_timeout: 30
  ) { |h| h.get(uri.request_uri, 'User-Agent' => 'Mozilla/5.0') }
  raise "HTTP #{response.code}" unless response.is_a?(Net::HTTPSuccess)
  ext   = File.extname(uri.path).downcase.presence || ".jpg"
  ext   = ".jpg" unless %w[.jpg .jpeg .png .webp .gif].include?(ext)
  ct    = case ext
          when ".jpg", ".jpeg" then "image/jpeg"
          when ".webp"         then "image/webp"
          when ".gif"          then "image/gif"
          else "image/png"
          end
  fname = File.basename(uri.path).presence || "image#{ext}"
  [response.body, fname, ct]
end

product_done = {}  # product_id → true, only attach 1 image per product
matched = 0; errors = 0; skipped = 0

CSV.parse(csv_data, headers: true, liberal_parsing: true) do |row|
  ean   = row["EAN/UPC"].to_s.strip
  title = row["product name"].to_s.strip

  # Try Image direct link 1 first, then 2-6
  image_url = nil
  (1..6).each do |i|
    url = row["Image direct link #{i}"].to_s.strip
    if url.start_with?("http")
      image_url = url
      break
    end
  end

  next unless image_url && ean.present?

  variant = variants_by_barcode[ean]
  unless variant
    skipped += 1
    next
  end

  # Only one image per product (master variant)
  product_id = variant.product_id
  next if product_done[product_id]
  product_done[product_id] = true

  master_v = Spree::Variant.find_by(product_id: product_id, is_master: true)
  next unless master_v

  begin
    data, fname, ct = fetch_image(image_url)
    img = Spree::Image.new(viewable: master_v, alt: title, position: 1)
    img.type = 'Spree::Image'
    img.attachment.attach(io: StringIO.new(data), filename: fname, content_type: ct)
    img.save!
    matched += 1
    print "C"
    STDOUT.flush
  rescue => e
    errors += 1
    print "!"
    STDOUT.flush
  end
end

puts "\n"
puts "Cabrinha products with images: #{matched}"
puts "No barcode match: #{skipped}"
puts "Errors: #{errors}"
puts "Done: #{Time.current}"
