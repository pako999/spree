# frozen_string_literal: true
#
# Sets up per-country EU VAT rates so each member state is charged its own
# correct rate instead of a flat 22% (Slovenian) rate.
#
# Run via:  kamal app exec --reuse "bin/rails runner script/setup_eu_vat_rates.rb"
#
# Safe to re-run — skips countries that already have a dedicated zone/rate.

TAX_CATEGORY_ID = 1   # "Default" — same as existing EU VAT rate
INCLUDED_IN_PRICE = true

EU_VAT_RATES = {
  'AT' => { name: 'Austria',     rate: 0.20 },
  'BE' => { name: 'Belgium',     rate: 0.21 },
  'BG' => { name: 'Bulgaria',    rate: 0.20 },
  'HR' => { name: 'Croatia',     rate: 0.25 },
  'CY' => { name: 'Cyprus',      rate: 0.19 },
  'CZ' => { name: 'Czechia',     rate: 0.21 },
  'DK' => { name: 'Denmark',     rate: 0.25 },
  'EE' => { name: 'Estonia',     rate: 0.22 },
  'FI' => { name: 'Finland',     rate: 0.255 },
  'FR' => { name: 'France',      rate: 0.20 },
  'DE' => { name: 'Germany',     rate: 0.19 },
  'GR' => { name: 'Greece',      rate: 0.24 },
  'HU' => { name: 'Hungary',     rate: 0.27 },
  'IE' => { name: 'Ireland',     rate: 0.23 },
  'IT' => { name: 'Italy',       rate: 0.22 },
  'LV' => { name: 'Latvia',      rate: 0.21 },
  'LT' => { name: 'Lithuania',   rate: 0.21 },
  'LU' => { name: 'Luxembourg',  rate: 0.17 },
  'MT' => { name: 'Malta',       rate: 0.18 },
  'NL' => { name: 'Netherlands', rate: 0.21 },
  'PL' => { name: 'Poland',      rate: 0.23 },
  'PT' => { name: 'Portugal',    rate: 0.23 },
  'RO' => { name: 'Romania',     rate: 0.19 },
  'SK' => { name: 'Slovakia',    rate: 0.23 },
  'SI' => { name: 'Slovenia',    rate: 0.22 },
  'ES' => { name: 'Spain',       rate: 0.21 },
  'SE' => { name: 'Sweden',      rate: 0.25 }
}.freeze

puts "=== EU per-country VAT rate setup ==="
puts

tax_category = Spree::TaxCategory.find(TAX_CATEGORY_ID)
created = 0
skipped = 0

EU_VAT_RATES.each do |iso, info|
  country = Spree::Country.find_by(iso: iso)
  unless country
    puts "  SKIP #{iso} — country not found in DB"
    skipped += 1
    next
  end

  zone_name = "#{iso} VAT Zone"

  # Create zone if it doesn't exist yet
  zone = Spree::Zone.find_by(name: zone_name)
  unless zone
    zone = Spree::Zone.create!(
      name: zone_name,
      description: "#{info[:name]} VAT zone",
      kind: 'country'
    )
    zone.zone_members.create!(zoneable: country)
    puts "  Created zone: #{zone_name}"
  end

  rate_name = "#{info[:name]} VAT"
  existing_rate = Spree::TaxRate.find_by(name: rate_name, zone: zone)

  if existing_rate
    puts "  SKIP #{iso} — rate '#{rate_name}' already exists (#{(existing_rate.amount * 100).round(2)}%)"
    skipped += 1
    next
  end

  rate = Spree::TaxRate.new(
    name:               rate_name,
    amount:             info[:rate],
    zone:               zone,
    tax_category:       tax_category,
    included_in_price:  INCLUDED_IN_PRICE,
    show_rate_in_label: true
  )
  rate.build_calculator(type: 'Spree::Calculator::DefaultTax')
  rate.save!

  puts "  Created: #{info[:name]} (#{iso}) — #{(info[:rate] * 100).round(2)}%"
  created += 1
end

puts
puts "Done — #{created} rates created, #{skipped} skipped."
puts

# Remove the old catch-all EU 22% rate so it no longer matches any EU country
old_rate = Spree::TaxRate.find_by(name: 'EU VAT')
if old_rate
  old_rate.destroy!
  puts "Removed old catch-all 'EU VAT' 22% rate (id=#{old_rate.id})."
else
  puts "Old 'EU VAT' rate not found (already removed)."
end
