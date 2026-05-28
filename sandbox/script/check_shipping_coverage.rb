#!/usr/bin/env ruby
# frozen_string_literal: true
#
# Shipping coverage audit — answers "can we ship to every country?"
#
# In Spree a customer can only complete checkout for a country when BOTH are true:
#   1. The country is selectable in the address form  → it belongs to the
#      store's checkout_zone (or no checkout_zone is set = all countries).
#   2. That country belongs to at least one Zone that has a (frontend-visible)
#      Shipping Method with a working calculator.
# If either is missing the customer is blocked. This script reports the gaps.
#
# Run on the server:
#   docker cp sandbox/script/check_shipping_coverage.rb surf-store:/rails/tmp/
#   ssh ubuntu@46.224.5.25 "docker exec surf-store bundle exec rails runner /rails/tmp/check_shipping_coverage.rb"
# or:
#   kamal app exec --reuse "bin/rails runner script/check_shipping_coverage.rb"

def zone_country_isos(zone)
  isos = []
  zone.zone_members.includes(:zoneable).each do |zm|
    z = zm.zoneable
    next unless z
    case z
    when Spree::Country then isos << z.iso
    when Spree::State   then isos << z.country&.iso
    end
  end
  isos.compact.uniq
end

def frontend_visible?(sm)
  # Spree has used a few mechanisms over versions; be liberal.
  if sm.respond_to?(:display_on) && sm.display_on.present?
    %w[both front_end].include?(sm.display_on.to_s)
  elsif sm.respond_to?(:available_to_all)
    true # visibility-by-user list; still offered at checkout
  else
    true
  end
end

puts "=" * 72
puts "SHIPPING COVERAGE AUDIT  (#{Time.now.utc.iso8601})"
puts "=" * 72

store = Spree::Store.default
puts "\nStore: #{store.name} (#{store.url})"

# ── 1. Checkout zone (which countries are selectable in the address form) ──
checkout_zone = store.respond_to?(:checkout_zone) ? store.checkout_zone : nil
if checkout_zone
  selectable_isos = zone_country_isos(checkout_zone)
  puts "Checkout zone: '#{checkout_zone.name}' → #{selectable_isos.size} selectable countries"
else
  selectable_isos = Spree::Country.pluck(:iso)
  puts "Checkout zone: (none set) → ALL #{selectable_isos.size} countries selectable"
end

all_isos = Spree::Country.pluck(:iso)

# ── 2. Shipping methods → which countries each can ship to ─────────────────
puts "\n" + "-" * 72
puts "SHIPPING METHODS"
puts "-" * 72
covered = {} # iso => [method names]
Spree::ShippingMethod.includes(:zones, :calculator).order(:name).each do |sm|
  isos = sm.zones.flat_map { |z| zone_country_isos(z) }.uniq
  calc = sm.calculator
  calc_desc =
    if calc.nil?
      "NO CALCULATOR (!)"
    else
      pref = calc.respond_to?(:preferred_amount) ? calc.preferred_amount : nil
      "#{calc.class.name.demodulize}#{pref ? " = #{pref}" : ''}"
    end
  vis = frontend_visible?(sm) ? "frontend" : "ADMIN-ONLY (!)"

  puts "\n• #{sm.name}"
  puts "    zones:      #{sm.zones.map(&:name).join(', ').presence || 'NONE (!)'}"
  puts "    countries:  #{isos.size}"
  puts "    calculator: #{calc_desc}"
  puts "    visibility: #{vis}"

  next unless frontend_visible?(sm)
  next if sm.zones.empty? || calc.nil?

  isos.each { |iso| (covered[iso] ||= []) << sm.name }
end

# ── 3. Coverage gaps ───────────────────────────────────────────────────────
puts "\n" + "=" * 72
puts "COVERAGE RESULT"
puts "=" * 72

shippable    = covered.keys
selectable   = selectable_isos

# A) selectable at checkout but NO shipping method → customer gets stuck
stuck = (selectable - shippable).sort
# B) has a shipping method but NOT selectable at checkout → can't enter address
unreachable = (shippable - selectable).sort
# C) countries in DB with neither
no_method_at_all = (all_isos - shippable).sort

iso_name = Spree::Country.pluck(:iso, :name).to_h

puts "\nSelectable at checkout: #{selectable.size} countries"
puts "Have a shipping method: #{shippable.size} countries"

if stuck.empty?
  puts "\n[OK] Every selectable country has at least one shipping method."
else
  puts "\n[BLOCKED] #{stuck.size} countries are selectable at checkout but have NO shipping method"
  puts "          (customer reaches the delivery step and cannot continue):"
  stuck.each { |iso| puts "   - #{iso}  #{iso_name[iso]}" }
end

unless unreachable.empty?
  puts "\n[NOTE] #{unreachable.size} countries have a shipping method but are NOT in the checkout zone"
  puts "       (address form won't let customers there check out):"
  unreachable.first(60).each { |iso| puts "   - #{iso}  #{iso_name[iso]}" }
end

puts "\nCountries in DB with NO shipping method whatsoever: #{no_method_at_all.size}"

# ── 4. Zones with no shipping method ───────────────────────────────────────
puts "\n" + "-" * 72
unused = Spree::Zone.includes(:shipping_methods).select { |z| z.shipping_methods.empty? }
if unused.any?
  puts "Zones NOT attached to any shipping method (#{unused.size}):"
  unused.each { |z| puts "   - #{z.name} (#{z.zone_members.count} members)" }
else
  puts "All zones are attached to at least one shipping method."
end

puts "\nDone."
