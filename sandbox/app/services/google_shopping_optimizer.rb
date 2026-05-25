# frozen_string_literal: true

# GoogleShoppingOptimizer
# Centralised logic for title building, brand normalisation, product-type
# detection, custom labels and feed exclusions.
# All methods are module-level so they can be called without instantiation.
module GoogleShoppingOptimizer
  # ── Brand normalisation ─────────────────────────────────────────────────────
  BRAND_NORMALIZE = {
    'ION Water'                   => 'ION',
    'ION Bike'                    => 'ION',
    'ION'                         => 'ION',
    'Duotone Kiteboarding'        => 'Duotone',
    'Duotone Windsurfing'         => 'Duotone',
    'Duotone Foilwing'            => 'Duotone',
    'Duotone Wing Foiling'        => 'Duotone',
    'Duotone Foiling & Electric'  => 'Duotone',
    'Duotone Apparel'             => 'Duotone',
    'Duotone SUP'                 => 'Duotone',
    'Duotone'                     => 'Duotone',
    'Fanatic SUP'                 => 'Fanatic',
    'Fanatic Windsurfing'         => 'Fanatic',
    'Fanatic X'                   => 'Fanatic',
    'Fanatic'                     => 'Fanatic',
    'Neilpryde'                   => 'NeilPryde',
    'NEILPRYDE'                   => 'NeilPryde',
    'neilpryde'                   => 'NeilPryde',
    'NeilPryde'                   => 'NeilPryde',
    'TABOU'                       => 'Tabou',
    'tabou'                       => 'Tabou',
    'Tabou'                       => 'Tabou',
    'JP Australia'                => 'JP Australia',
    'jp australia'                => 'JP Australia',
    'Cabrinha'                    => 'Cabrinha',
    'Nobile'                      => 'Nobile',
    'Gaastra'                     => 'Gaastra',
    'Point-7'                     => 'Point-7',
    'Point7'                      => 'Point-7',
    'Mystic'                      => 'Mystic',
    'Prolimit'                    => 'Prolimit',
    'Manera'                      => 'Manera',
    'Dakine'                      => 'Dakine',
    'North'                       => 'North',
    'Core'                        => 'CORE',
    'CORE'                        => 'CORE',
    'F-One'                       => 'F-One',
    'Slingshot'                   => 'Slingshot',
    'Eleveight'                   => 'Eleveight',
    'Airush'                      => 'Airush',
    'Ozone'                       => 'Ozone',
    'Flysurfer'                   => 'Flysurfer',
    'RRD'                         => 'RRD',
    'Severne'                     => 'Severne',
    'Naish'                       => 'Naish',
    'Starboard'                   => 'Starboard',
    'Simmer'                      => 'Simmer',
  }.freeze

  # Sub-brand noise words to strip when cleaning the model name from the title
  BRAND_NOISE_WORDS = %w[
    Water Bike Kiteboarding Windsurfing Foilwing Foiling Electric Wing Apparel
  ].freeze

  OLD_SEASONS = %w[2023 2024 2025].freeze

  EXCLUSION_PATTERNS = [
    /worry.?free.?delivery/i,
    /gift.?card/i,
    /shipping.?insurance/i,
    /shipping.?protection/i,
    /digital.?download/i,
  ].freeze

  # ── Public API ───────────────────────────────────────────────────────────────

  def self.normalize_brand(raw)
    return '' if raw.blank?
    BRAND_NORMALIZE[raw.strip] || raw.strip
  end

  # Returns true when the product/variant should be dropped from the feed.
  # total_stock: Integer (sum of count_on_hand across all stock locations)
  # backorderable: Boolean
  def self.exclude?(product_name, total_stock, backorderable)
    return true if EXCLUSION_PATTERNS.any? { |p| product_name.match?(p) }

    season = extract_year(product_name.to_s)
    OLD_SEASONS.include?(season) && total_stock <= 0 && !backorderable
  end

  def self.extract_year(title)
    m = title.to_s.match(/20(2[3-9]|3[0-9])/)
    m ? m[0] : nil
  end

  # Availability string for Google Shopping
  def self.availability(total_stock, backorderable)
    return 'preorder'      if backorderable && total_stock <= 0
    return 'in_stock'      if total_stock > 0
    'out_of_stock'
  end

  # ── Product-type detection ───────────────────────────────────────────────────
  # Returns a short human-readable type string used both in the title and as
  # the g:product_type value.
  # taxon_permalinks: Array<String>
  # raw_brand: taxon name (e.g. "ION Water", "Duotone Kiteboarding")
  # title: product.name
  def self.detect_product_type(title, raw_brand, taxon_permalinks)
    t    = title.to_s.downcase
    perms = Array(taxon_permalinks)

    # Taxon-first (most reliable)
    return kite_subtype(t)              if perms.any? { |p| p.include?('kitesurfing/kites') }
    return kiteboard_subtype(t)         if perms.any? { |p| p.include?('kitesurfing/kiteboards') }
    return kite_accessory_subtype(t)    if perms.any? { |p| p.include?('kitesurfing/kite-accessories') || p.include?('kitesurfing/kite-foil') }
    return kite_generic_subtype(t)      if perms.any? { |p| p.include?('kitesurfing') }
    return 'Wing Foiling Wing'          if perms.any? { |p| p.include?('wingfoil/wings') }
    return 'Wing Foiling Board'         if perms.any? { |p| p.include?('wingfoil/wing-boards') }
    return 'Hydrofoil'                  if perms.any? { |p| p.include?('wingfoil/wing-foils') }
    return wing_foil_subtype(t)         if perms.any? { |p| p.include?('wingfoil') }
    return 'Windsurfing Sail'           if perms.any? { |p| p.include?('windsurf/windsurf-sails') }
    return 'Windsurfing Board'          if perms.any? { |p| p.include?('windsurf/windsurf-boards') }
    return windsurf_gear_subtype(t)     if perms.any? { |p| p.include?('windsurf/windsurf-gear') }
    return windsurf_harness_subtype(t)  if perms.any? { |p| p.include?('windsurf/windsurf-harnesses') }
    return windsurf_generic_subtype(t)  if perms.any? { |p| p.include?('windsurf') }
    return 'SUP Paddle'                 if perms.any? { |p| p.include?('sup-board/sup-paddles') }
    return 'SUP Board'                  if perms.any? { |p| p.include?('sup-board') }
    return 'Neoprene Gloves'            if perms.any? { |p| p.include?('neoprene-accessories/gloves') }
    return 'Surf Shoes'                 if perms.any? { |p| p.include?('neoprene-accessories/surf-shoes') }
    return wetsuit_acc_subtype(t)       if perms.any? { |p| p.include?('neoprene-accessories') }
    return wetsuit_subtype(t)           if perms.any? { |p| p.include?('wetsuits') }
    return 'Boardshorts'                if perms.any? { |p| p.include?('apparel/boardshorts') }
    return 'Cap'                        if perms.any? { |p| p.include?('apparel/cap') }
    return 'Poncho'                     if perms.any? { |p| p.include?('apparel/ponchos') }
    return 'Jacket'                     if perms.any? { |p| p.include?('apparel/coats') }
    return apparel_subtype(t)           if perms.any? { |p| p.include?('apparel') }
    return 'E-Foil'                     if perms.any? { |p| p.include?('e-foil') }

    # Keyword fallback
    keyword_detect(t)
  end

  # ── Title builder ────────────────────────────────────────────────────────────
  # Format: [Brand] [Model] [Product Type] [Year] [Color] [Size]
  def self.build_title(product_name, raw_brand, product_type, color, size)
    brand = normalize_brand(raw_brand)
    year  = extract_year(product_name.to_s)
    model = clean_model(product_name.to_s, brand, raw_brand, year)

    variant = [color, size].compact.reject(&:blank?).join(' ')
    parts   = [brand, model, product_type, year, variant]
    title   = parts.compact.reject(&:blank?).join(' ').gsub(/\s{2,}/, ' ').strip
    title.length > 150 ? "#{title[0...147]}..." : title
  end

  # ── Custom labels ────────────────────────────────────────────────────────────

  def self.custom_label_0_margin(product_type)
    return 'mid_margin' if product_type.blank?
    pt = product_type.downcase
    high = %w[cap t-shirt hoodie bag gloves protector strap leash pump hood boots socks fin pigtail bridle bladder poncho rashguard shoes repair]
    low  = %w[kite sail board wing mast hydrofoil foil e-foil]
    return 'high_margin' if high.any? { |k| pt.include?(k) }
    return 'low_margin'  if low.any?  { |k| pt.include?(k) }
    'mid_margin'
  end

  def self.custom_label_2_season(title)
    extract_year(title.to_s) || 'evergreen'
  end

  def self.custom_label_3_price_bucket(price)
    p = price.to_f
    return 'unknown'    if p.zero?
    return 'under_100'  if p < 100
    return '100_to_300' if p < 300
    return '300_to_800' if p < 800
    return '800_to_1500' if p < 1500
    '1500_plus'
  end

  # ── Private helpers ──────────────────────────────────────────────────────────

  def self.clean_model(name, brand, raw_brand, year)
    m = name.dup
    m = m.gsub(/\b#{Regexp.escape(year)}\b/, '') if year.present?
    [brand, raw_brand].uniq.compact.each do |b|
      b.to_s.split(/\s+/).each { |w| m = m.gsub(/\b#{Regexp.escape(w)}\b/i, '') if w.length > 2 }
    end
    BRAND_NOISE_WORDS.each { |w| m = m.gsub(/\b#{Regexp.escape(w)}\b/i, '') }
    m.gsub(/[,\-–—]+$/, '').gsub(/\s{2,}/, ' ').strip
  end
  private_class_method :clean_model

  def self.kite_subtype(t)
    return 'Parawing' if t.match?(/parawing|para.wing/)
    'Kitesurfing Kite'
  end
  private_class_method :kite_subtype

  def self.kiteboard_subtype(t)
    return 'Kite Foil Board' if t.match?(/foil/)
    return 'Kite Surfboard'  if t.match?(/surf.?board|directional/)
    'Kiteboard'
  end
  private_class_method :kiteboard_subtype

  def self.kite_accessory_subtype(t)
    return 'Kite Control Bar' if t.match?(/\bbar\b/)
    return 'Kite Harness'     if t.match?(/harness/)
    return 'Hydrofoil'        if t.match?(/foil/)
    return 'Kite Pump'        if t.match?(/pump/)
    return 'Kite Leash'       if t.match?(/leash/)
    return 'Kite Pads'        if t.match?(/\bpad/)
    'Kite Accessory'
  end
  private_class_method :kite_accessory_subtype

  def self.kite_generic_subtype(t)
    return 'Kiteboard'        if t.match?(/\bboard\b/)
    return 'Kite Control Bar' if t.match?(/\bbar\b/)
    return 'Kite Harness'     if t.match?(/harness/)
    return 'Hydrofoil'        if t.match?(/foil/)
    'Kitesurfing'
  end
  private_class_method :kite_generic_subtype

  def self.wing_foil_subtype(t)
    return 'Wing Foiling Wing'  if t.match?(/\bwing\b/)
    return 'Wing Foiling Board' if t.match?(/\bboard\b/)
    return 'Hydrofoil'          if t.match?(/foil/)
    return 'Wing Harness'       if t.match?(/harness/)
    'Wing Foiling'
  end
  private_class_method :wing_foil_subtype

  def self.windsurf_gear_subtype(t)
    return 'Windsurfing Mast'      if t.match?(/\bmast\b/)
    return 'Windsurfing Boom'      if t.match?(/\bboom\b/)
    return 'Windsurfing Extension' if t.match?(/extension/)
    return 'Windsurfing Base'      if t.match?(/\bbase\b/)
    return 'Windsurfing Rig'       if t.match?(/\brig\b/)
    'Windsurfing Gear'
  end
  private_class_method :windsurf_gear_subtype

  def self.windsurf_harness_subtype(t)
    return 'Windsurfing Spreader Bar' if t.match?(/spreader/)
    return 'Windsurfing Harness Hook' if t.match?(/hook/)
    'Windsurfing Harness'
  end
  private_class_method :windsurf_harness_subtype

  def self.windsurf_generic_subtype(t)
    return 'Windsurfing Sail'  if t.match?(/\bsail\b/)
    return 'Windsurfing Board' if t.match?(/\bboard\b/)
    return 'Windsurfing Mast'  if t.match?(/\bmast\b/)
    return 'Windsurfing Boom'  if t.match?(/\bboom\b/)
    'Windsurfing'
  end
  private_class_method :windsurf_generic_subtype

  def self.wetsuit_subtype(t)
    return 'Shorty Wetsuit' if t.match?(/shorty/)
    return 'Neoprene Top'   if t.match?(/neokini|neoprene.top/)
    return 'Drysuit'        if t.match?(/dry.?suit/)
    return 'Neoprene Vest'  if t.match?(/\bvest\b/)
    'Wetsuit'
  end
  private_class_method :wetsuit_subtype

  def self.wetsuit_acc_subtype(t)
    return 'Neoprene Hood'   if t.match?(/hood/)
    return 'Neoprene Gloves' if t.match?(/glove/)
    return 'Neoprene Boots'  if t.match?(/boot|shoe/)
    return 'Thermal Shirt'   if t.match?(/thermal|shirt/)
    return 'Rashguard'       if t.match?(/rash/)
    'Neoprene Accessory'
  end
  private_class_method :wetsuit_acc_subtype

  def self.apparel_subtype(t)
    return 'Hoodie'      if t.match?(/hoodie|hoody/)
    return 'T-Shirt'     if t.match?(/t-shirt|tee\b/)
    return 'Jacket'      if t.match?(/jacket|coat/)
    return 'Rashguard'   if t.match?(/rash/)
    return 'Boardshorts' if t.match?(/short/)
    return 'Cap'         if t.match?(/\bcap\b|hat/)
    return 'Bag'         if t.match?(/\bbag\b/)
    'Apparel'
  end
  private_class_method :apparel_subtype

  def self.keyword_detect(t)
    return 'Kitesurfing Kite'  if t.match?(/\bkite\b/) && !t.match?(/board|foil/)
    return 'Kiteboard'         if t.match?(/kite.?board|twintip|twin.tip/)
    return 'Windsurfing Sail'  if t.match?(/\bsail\b/)
    return 'Windsurfing Board' if t.match?(/windsurf.*board|freeride.*board/)
    return 'Wing Foiling Wing' if t.match?(/\bwing\b/)
    return 'Hydrofoil'         if t.match?(/hydro.?foil|foil/)
    return 'Wetsuit'           if t.match?(/wetsuit|neo/)
    return 'Windsurfing Mast'  if t.match?(/\bmast\b/)
    return 'Windsurfing Boom'  if t.match?(/\bboom\b/)
    return 'Harness'           if t.match?(/harness/)
    return 'SUP Board'         if t.match?(/\bsup\b/)
    return 'Leash'             if t.match?(/leash/)
    return 'Bag'               if t.match?(/\bbag\b/)
    return 'Cap'               if t.match?(/\bcap\b/)
    'Water Sports Equipment'
  end
  private_class_method :keyword_detect
end
