#!/usr/bin/env ruby
# frozen_string_literal: true
# Lean image importer: one sheet at a time, low memory.
# Run: SHEET_URL=... SHEET_NAME=... bundle exec rails runner /rails/tmp/import_sheet_images.rb

require 'csv'
require 'open-uri'
require 'net/http'

sheet_url  = ENV.fetch('SHEET_URL')
sheet_name = ENV.fetch('SHEET_NAME', 'Sheet')

puts "=== #{sheet_name} ==="
puts "Downloading CSV..."

csv_data = URI.open(
  sheet_url,
  "User-Agent" => "Mozilla/5.0",
  read_timeout: 60, open_timeout: 20
).read
puts "  #{csv_data.lines.count} rows"

# Build variant lookup
variants_by_barcode = {}
Spree::Variant.where.not(barcode: [nil, ""]).select(:id, :barcode, :is_master, :product_id).find_each do |v|
  bc = v.barcode.to_s.strip
  next if bc.blank?
  # prefer non-master
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
  ext  = File.extname(uri.path).downcase.presence || ".jpg"
  ext  = ".jpg" unless %w[.jpg .jpeg .png .webp .gif].include?(ext)
  ct   = case ext
         when ".jpg", ".jpeg" then "image/jpeg"
         when ".webp"         then "image/webp"
         when ".gif"          then "image/gif"
         else "image/png"
         end
  fname = File.basename(uri.path).presence || "image#{ext}"
  [response.body, fname, ct]
end

master_done   = {}   # product_id => true (only attach master img once per product)
master_ok = 0; variant_ok = 0; errors = 0; skipped = 0

CSV.parse(csv_data, headers: true, liberal_parsing: true) do |row|
  barcode       = row["Variant Barcode"].to_s.strip
  image_src     = row["Image Src"].to_s.strip
  variant_image = row["Variant Image"].to_s.strip
  title         = row["Title"].to_s.strip

  # ── Master image (Image Src, one per product) ──────────────
  if image_src.start_with?("http") && barcode.present?
    v = variants_by_barcode[barcode]
    if v && !master_done[v.product_id]
      master_done[v.product_id] = true
      master_v = Spree::Variant.find_by(product_id: v.product_id, is_master: true)
      if master_v
        begin
          data, fname, ct = fetch_image(image_src)
          img = Spree::Image.new(viewable: master_v, alt: title, position: 1)
          img.type = 'Spree::Image'
          img.attachment.attach(io: StringIO.new(data), filename: fname, content_type: ct)
          img.save!
          master_ok += 1
          print "M"
        rescue => e
          errors += 1
          print "!"
        end
        STDOUT.flush
      end
    end
  end

  # ── Variant-specific image (Variant Image, matched by barcode) ──
  next unless variant_image.start_with?("http") && barcode.present?

  variant = variants_by_barcode[barcode]
  unless variant
    skipped += 1
    next
  end

  # Load full variant object
  full_variant = Spree::Variant.find(variant.id)

  begin
    data, fname, ct = fetch_image(variant_image)
    alt = [title, full_variant.options_text].reject(&:blank?).join(" ")
    img = Spree::Image.new(viewable: full_variant, alt: alt, position: 1)
    img.type = 'Spree::Image'
    img.attachment.attach(io: StringIO.new(data), filename: fname, content_type: ct)
    img.save!
    variant_ok += 1
    print "v"
  rescue => e
    errors += 1
    print "!"
  end
  STDOUT.flush
end

puts "\n"
puts "Master images:  #{master_ok}"
puts "Variant images: #{variant_ok}"
puts "No barcode match: #{skipped}"
puts "Errors: #{errors}"
puts "Done: #{Time.current}"
