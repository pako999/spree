# frozen_string_literal: true
# Fix GA/Tabou imported products:
#  1. Replace link-based description with real HTML fetched from cdn.gaastra.io
#  2. Reassign to correct leaf-level taxons (masts, booms, extensions, rigs)
# Run: bin/kamal app exec --reuse "bin/rails runner /rails/script/fix_ga_tabou_descriptions_and_taxons.rb"

require 'csv'
require 'net/http'
require 'uri'
require 'open-uri'

CSV_URL = 'https://docs.google.com/spreadsheets/d/1Sr4GYYICLOMUS3g_JFm4v3ildnSPWfHw9Ea5AeeDm3I/export?format=csv'

# Corrected leaf-level taxon map (fixes from original import)
CORRECT_CATEGORY_MAP = {
  'Windsurfmasts'        => 'categories/windsurf/windsurf-gear/windsurf-mast',
  'WindsurfingBooms'     => 'categories/windsurf/windsurf-gear/windsurf-boom',
  'Mastaccessories'      => 'categories/windsurf/windsurf-gear/windsurf-extension',
  'Riggs'                => 'categories/windsurf/windsurf-gear/windsurf-rig',
  'Harness'              => 'categories/windsurf/windsurf-harnesses/windsurf-harness',
  'Kiteparts'            => 'categories/kitesurfing/kite-accessories/spare-parts',
}.freeze

def fetch_description(url)
  return nil if url.blank?
  uri = URI.parse(url)
  tries = 0
  loop do
    tries += 1
    return nil if tries > 3
    res = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == 'https', open_timeout: 10, read_timeout: 20) do |http|
      http.request(Net::HTTP::Get.new(uri))
    end
    case res
    when Net::HTTPSuccess
      html = res.body.to_s.force_encoding('UTF-8').encode('UTF-8', invalid: :replace, undef: :replace)
      # Strip meta/script/style tags, keep only body content
      html.gsub!(/<meta[^>]*>/i, '')
      html.gsub!(/<script[^>]*>.*?<\/script>/mi, '')
      html.gsub!(/<style[^>]*>.*?<\/style>/mi, '')
      html.strip!
      return html.presence
    when Net::HTTPRedirection
      uri = URI.parse(res['location'])
    else
      return nil
    end
  end
rescue => e
  puts " [fetch err: #{e.message.truncate(60)}]"
  nil
end

puts "Downloading CSV..."
csv_data = URI.open(CSV_URL, 'User-Agent' => 'Mozilla/5.0').read.force_encoding('UTF-8')

# Build product groups (V rows → variants), same logic as import
products_data = []
current_group = nil

CSV.parse(csv_data, headers: true, encoding: 'UTF-8') do |row|
  h = row.to_h.transform_values { |v| v&.encode('UTF-8', invalid: :replace, undef: :replace)&.strip }
  sku = h['SKU'].to_s.strip
  next if sku.blank?

  if sku.start_with?('V')
    current_group = { v_row: h, variants: [] }
    products_data << current_group
  else
    current_group ||= { v_row: nil, variants: [] }.tap { |g| products_data << g }
    current_group[:variants] << h
  end
end

products_data.reject! { |g| g[:variants].empty? }
puts "Product groups in CSV: #{products_data.size}"

# Preload corrected taxons
corrected_taxons = CORRECT_CATEGORY_MAP.transform_values { |p| Spree::Taxon.find_by(permalink: p) }

# Report missing taxons
corrected_taxons.each do |cat, taxon|
  puts "WARNING: taxon not found for #{cat}: #{CORRECT_CATEGORY_MAP[cat]}" if taxon.nil?
end

desc_fixed   = 0
taxon_fixed  = 0
not_found    = 0
desc_errors  = 0
total        = products_data.size

products_data.each_with_index do |group, idx|
  v_row    = group[:v_row]
  variants = group[:variants]

  # Find the product by any of its barcodes
  barcodes = variants.map { |r| r['BARCODE'] }.compact.reject(&:empty?).uniq
  next if barcodes.empty?

  product = Spree::Variant.where(barcode: barcodes).first&.product
  if product.nil?
    not_found += 1
    next
  end

  category_key = (v_row || variants.first)['ItmsGrp1'].to_s.strip
  desc_url     = v_row ? v_row['DESCRIPTION'].to_s.strip : nil
  product_name = product.name

  print "\n[#{idx + 1}/#{total}] #{product_name}"

  # --- Fix description ---
  current_desc = product.description.to_s
  if desc_url.present? && current_desc.include?('cdn.gaastra.io') && current_desc.include?('href')
    print " [desc...]"
    html = fetch_description(desc_url)
    if html.present?
      product.update_column(:description, html)
      desc_fixed += 1
      print " ✓desc"
    else
      desc_errors += 1
      print " ✗desc"
    end
  end

  # --- Fix taxons ---
  correct_taxon = corrected_taxons[category_key]
  next unless correct_taxon

  current_taxon_ids = product.taxons.pluck(:id)
  unless current_taxon_ids.include?(correct_taxon.id)
    # Find the old (wrong) taxon to remove
    # The wrong taxon was the parent of the correct one (e.g. windsurf-gear instead of windsurf-mast)
    parent_taxon = correct_taxon.parent
    new_taxons = product.taxons.reject { |t| t.id == parent_taxon&.id }
    new_taxons << correct_taxon
    product.taxons = new_taxons.uniq
    taxon_fixed += 1
    print " ✓taxon→#{correct_taxon.name}"
  end
end

puts "\n\n#{'=' * 60}"
puts "Fix complete"
puts "  Descriptions fixed : #{desc_fixed}"
puts "  Description errors : #{desc_errors}"
puts "  Taxons fixed       : #{taxon_fixed}"
puts "  Products not found : #{not_found}"
puts "  Total CSV groups   : #{total}"
