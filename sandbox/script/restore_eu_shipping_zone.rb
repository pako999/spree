#!/usr/bin/env ruby
# Recreates the EU shipping zone (deleted during VAT fix) and re-attaches
# it to any shipping methods that currently have no zone.
#
# Run via: kamal app exec --reuse "bin/rails runner script/restore_eu_shipping_zone.rb"

EU_COUNTRIES = %w[
  AT BE BG HR CY CZ DK EE FI FR DE GR HU IE IT LV LT LU MT NL PL PT RO SK SI ES SE
].freeze

puts "=== Restore EU Shipping Zone ==="
puts

# Check if an EU zone already exists (different from the per-country VAT zones)
existing = Spree::Zone.find_by(name: 'EU')
if existing
  puts "EU zone already exists (id=#{existing.id}) — checking members..."
else
  puts "Creating EU zone..."
  existing = Spree::Zone.create!(
    name: 'EU',
    description: 'European Union — all 27 member states',
    kind: 'country'
  )
  puts "  Created zone id=#{existing.id}"
end

# Add missing country members
current_iso = existing.zone_members.includes(:zoneable).map { |zm| zm.zoneable&.iso }.compact
EU_COUNTRIES.each do |iso|
  next if current_iso.include?(iso)

  country = Spree::Country.find_by(iso: iso)
  unless country
    puts "  SKIP #{iso} — not found in DB"
    next
  end

  existing.zone_members.create!(zoneable: country)
  puts "  Added #{iso} (#{country.name})"
end

puts "  EU zone now has #{existing.zone_members.count} members"
puts

# Find shipping methods with no zone and re-attach them
puts "=== Shipping Methods with no zone ==="
orphaned = Spree::ShippingMethod.includes(:zones).select { |sm| sm.zones.empty? }

if orphaned.empty?
  puts "  No orphaned shipping methods found."
else
  orphaned.each do |sm|
    puts "  Attaching '#{sm.name}' → EU zone"
    sm.zones << existing unless sm.zones.include?(existing)
  end
end

puts
puts "Done."
