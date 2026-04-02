# frozen_string_literal: true
# Auto-categorize uncategorized products based on name keyword matching.
# Safe to re-run — only adds missing taxon associations, never removes existing ones.
# Run: bin/kamal app exec --reuse "bin/rails runner /rails/script/auto_categorize.rb"

# -----------------------------------------------------------------------
# Taxon ID map (from Categories taxonomy)
# -----------------------------------------------------------------------
T = {
  # Wetsuits
  wetsuits:           66,
  men_wetsuits:       349,
  shorty_men:         350,
  wetsuit_2mm_men:    351,
  wetsuit_3mm_men:    352,
  wetsuit_4mm_men:    353,
  wetsuit_5mm_men:    354,
  wetsuit_6mm_men:    355,
  women_wetsuits:     356,
  shorty_women:       357,
  wetsuit_2mm_women:  358,
  wetsuit_3mm_women:  359,
  wetsuit_4mm_women:  360,
  wetsuit_5mm_women:  361,
  wetsuit_6mm_women:  362,
  neo_accessories:    363,
  shoes:              267,
  gloves:             252,
  hoods:              247,
  thermal_shirts:     245,
  rashguards:         256,
  kids_wetsuits:      364,

  # SUP
  sup:                218,
  sup_boards:         390,
  sup_paddles:        391,
  sup_accessories:    392,
  sup_fins:           292,

  # Windsurf
  windsurf:           227,
  windsurf_boards:    51,
  windsurf_sails:     127,
  windsurf_masts:     132,
  windsurf_booms:     204,
  windsurf_extensions:130,
  windsurf_rigs:      212,
  windsurf_bases:     340,
  windsurf_harnesses: 239,
  harness_hooks:      97,
  harness_parts:      246,
  spreader_bars:      250,
  windsurf_foils:     257,
  windsurf_spare:     104,
  windsurf_bags:      184,
  windsurf_fins:      241,

  # Wing Foil
  wingfoil:           228,
  wings:              304,
  wing_booms:         234,
  wing_boards:        163,
  wing_foils:         162,
  wing_foil_sets:     45,
  wing_foil_parts:    207,
  wing_spare:         89,
  wing_bags:          167,
  foil_bags:          259,
  wing_leashes:       328,
  wing_bladders:      315,

  # Apparel
  apparel:            302,
  tops:               161,
  coats:              144,
  ponchos:            281,
  boardshorts:        286,
  caps:               126,
  lycra:              254,
  nylon_shirts:       253,
  sun_protection:     103,

  # Kitesurfing
  kitesurfing:        365,
  kites:              106,
  parawings:          314,
  kite_surf_boards:   206,
  twintip_boards:     62,
  kite_foil_boards:   291,
  kite_bars:          48,
  kite_pads:          56,
  kite_leashes:       123,
  pumps:              195,
  kite_spare:         93,
  chicken_loops:      98,
  kite_foil_parts:    172,
  foil_masts:         44,
  kitefoil_boards:    173,
  kite_harnesses:     146,
  helmets:            244,
  vests:              159,
  life_jackets:       341,

  # E-Foil
  efoil:              371,
  efoil_sets:         393,
  efoil_spare:        394,
}.freeze

# Preload all taxons
taxons = Spree::Taxon.where(id: T.values).index_by(&:id)

def t(key)
  taxons = @taxons
  taxons[T[key]]
end

@taxons = taxons

# -----------------------------------------------------------------------
# Rules: [keyword_patterns, taxon_keys]
# Evaluated in order — FIRST match wins per product.
# Patterns are case-insensitive regex tested against product name.
# -----------------------------------------------------------------------
RULES = [
  # ---- WETSUITS -------------------------------------------------------
  # Kids first (before gender rules)
  [/\bjunior\b|\bjr\b|\bkid/i,                           [:kids_wetsuits, :wetsuits]],
  # Women wetsuits by thickness
  [/6[\/.\\]5.*\bwom|\bwom.*6[\/.\\]5/i,                [:wetsuit_6mm_women, :women_wetsuits, :wetsuits]],
  [/5[\/.\\]4.*\bwom|\bwom.*5[\/.\\]4/i,                [:wetsuit_5mm_women, :women_wetsuits, :wetsuits]],
  [/4[\/.\\]3.*\bwom|\bwom.*4[\/.\\]3/i,                [:wetsuit_4mm_women, :women_wetsuits, :wetsuits]],
  [/3[\/.\\]2.*\bwom|\bwom.*3[\/.\\]2/i,                [:wetsuit_3mm_women, :women_wetsuits, :wetsuits]],
  [/2[\/.\\]2.*\bwom|\bwom.*2[\/.\\]2/i,                [:wetsuit_2mm_women, :women_wetsuits, :wetsuits]],
  [/shorty.*\bwom|\bwom.*shorty|hot.*shorty.*\bwom/i,   [:shorty_women, :women_wetsuits, :wetsuits]],
  [/zip.*top.*\bwom|long.*jane|long.*pant.*\bwom|v-back.*\bwom/i, [:women_wetsuits, :wetsuits]],
  [/\bwomen\b|\bwomens\b|\bwomen's\b/i,                 [:women_wetsuits, :wetsuits]],
  # Men wetsuits by thickness
  [/6[\/.\\]5/i,                                        [:wetsuit_6mm_men, :men_wetsuits, :wetsuits]],
  [/5[\/.\\]4/i,                                        [:wetsuit_5mm_men, :men_wetsuits, :wetsuits]],
  [/4[\/.\\]3/i,                                        [:wetsuit_4mm_men, :men_wetsuits, :wetsuits]],
  [/3[\/.\\]2/i,                                        [:wetsuit_3mm_men, :men_wetsuits, :wetsuits]],
  [/2[\/.\\]2/i,                                        [:wetsuit_2mm_men, :men_wetsuits, :wetsuits]],
  [/\bshorty\b/i,                                       [:shorty_men, :men_wetsuits, :wetsuits]],
  # Neoprene accessories
  [/\bhood\b/i,                                         [:hoods, :neo_accessories, :wetsuits]],
  [/\bglove/i,                                          [:gloves, :neo_accessories, :wetsuits]],
  [/\bbootie|\bshoe|\bsock.*neo|\bsurf.*shoe/i,         [:shoes, :neo_accessories, :wetsuits]],
  [/thermal.*shirt|rashguard|rash.*guard/i,             [:rashguards, :neo_accessories, :wetsuits]],
  [/\bthermal\b/i,                                      [:thermal_shirts, :neo_accessories, :wetsuits]],
  # Generic wetsuit
  [/wetsuit|neoprene.*suit|drysuit/i,                   [:wetsuits]],

  # ---- SUP ------------------------------------------------------------
  [/sup.*paddle|paddle.*sup/i,                          [:sup_paddles, :sup]],
  [/\bsup\b.*\bboard|\bboard.*\bsup\b|\bsup\b.*\binflat/i, [:sup_boards, :sup]],
  [/\bsup\b.*fin|\bsup\b.*leash|\bsup\b.*bag|\bpaddleboard/i, [:sup_accessories, :sup]],
  [/paddle.*float|paddle.*bag/i,                        [:sup_accessories, :sup]],

  # ---- WINDSURF -------------------------------------------------------
  [/\brig\b.*windsurf|windsurf.*\brig\b/i,              [:windsurf_rigs, :windsurf]],
  [/windsurf.*boom|\bboom\b.*windsurf/i,                [:windsurf_booms, :windsurf]],
  [/\bmast\b.*(windsurf|sail|rdm|sdm)|windsurf.*\bmast\b/i, [:windsurf_masts, :windsurf]],
  [/\bextension\b.*(windsurf|base|mast)|windsurf.*extension/i, [:windsurf_extensions, :windsurf]],
  [/\bbase\b.*(windsurf|mast)|windsurf.*\bbase\b/i,    [:windsurf_bases, :windsurf]],
  [/\bsail\b.*(windsurf|wave|freeride|race)|windsurf.*\bsail\b/i, [:windsurf_sails, :windsurf]],
  [/windsurf.*harness|waist.*kite|seat.*harness/i,      [:windsurf_harnesses, :windsurf]],
  [/spreader.*bar/i,                                    [:spreader_bars, :windsurf_harnesses, :windsurf]],
  [/harness.*hook|hook.*harness/i,                      [:harness_hooks, :windsurf_harnesses, :windsurf]],
  [/windsurf.*foil|foil.*windsurf/i,                    [:windsurf_foils, :windsurf]],
  [/windsurf.*fin|\bfin\b.*windsurf/i,                  [:windsurf_fins, :windsurf]],
  [/windsurf.*bag|sail.*bag/i,                          [:windsurf_bags, :windsurf]],
  [/windsurf.*board|\bboard.*(wave|freeride|race|freestyle|slalom)/i, [:windsurf_boards, :windsurf]],

  # ---- WING FOIL ------------------------------------------------------
  [/wing.*bladder|bladder.*wing/i,                      [:wing_bladders, :wingfoil]],
  [/wing.*leash|leash.*wing/i,                          [:wing_leashes, :wingfoil]],
  [/wing.*bag|bag.*wing/i,                              [:wing_bags, :wingfoil]],
  [/foil.*bag|bag.*foil/i,                              [:foil_bags, :wingfoil]],
  [/wing.*boom|boom.*wing/i,                            [:wing_booms, :wings, :wingfoil]],
  [/\bunit\b|\bego\b|\bslick\b|\bspeed\b wing|wing.*set.*carve|carve.*\d\.\d/i, [:wings, :wingfoil]],
  [/wing.*board|foil.*board.*wing|\bstroke\b.*board|\bsky.*free|\bskybrid/i, [:wing_boards, :wingfoil]],
  [/wing.*foil.*set|foil.*set.*wing/i,                  [:wing_foil_sets, :wing_foils, :wingfoil]],
  [/foil.*part|mast.*shim|foil.*screw|foil.*bolt|foil.*spacer/i, [:wing_foil_parts, :wing_foils, :wingfoil]],
  [/\bfoil\b.*(alu|carbon|alloy|mast|fuselage|front.*wing|back.*wing|stab)/i, [:wing_foils, :wingfoil]],
  [/wing.*spare|spare.*wing/i,                          [:wing_spare, :wingfoil]],
  [/\bwing\b/i,                                         [:wingfoil]],

  # ---- KITE -----------------------------------------------------------
  [/\bparawing\b/i,                                     [:parawings, :kites, :kitesurfing]],
  [/chicken.*loop|loop.*chicken/i,                      [:chicken_loops, :kite_accessories, :kitesurfing]],
  [/\bkite.*bar\b|\bcontrol.*bar\b|\bbar\b.*kite/i,    [:kite_bars, :kitesurfing]],
  [/kite.*pad|\bpad.*kite/i,                            [:kite_pads, :kitesurfing]],
  [/kite.*leash|leash.*kite|board.*leash/i,             [:kite_leashes, :kitesurfing]],
  [/\bpump\b/i,                                         [:pumps, :kitesurfing]],
  [/kite.*foil.*board|foil.*board.*kite/i,              [:kite_foil_boards, :kitesurfing]],
  [/kite.*foil|foil.*kite/i,                            [:kite_foil_parts, :kitesurfing]],
  [/kite.*harness|harness.*kite/i,                      [:kite_harnesses, :kitesurfing]],
  [/\bhelmet\b/i,                                       [:helmets, :kitesurfing]],
  [/\bvest\b|\bimpact.*vest/i,                          [:vests, :kitesurfing]],
  [/life.*jacket|\bjacket\b.*life/i,                    [:life_jackets, :kitesurfing]],
  [/kite.*surf.*board|kite.*board.*surf/i,              [:kite_surf_boards, :kitesurfing]],
  [/twintip|\btwin.*tip\b/i,                            [:twintip_boards, :kitesurfing]],
  [/\bkite\b.*board/i,                                  [:twintip_boards, :kitesurfing]],
  [/kite.*spare|spare.*kite|kite.*repair|bladder.*kite|strut.*kite|kite.*bladder/i, [:kite_spare, :kitesurfing]],
  [/\bkite\b/i,                                         [:kites, :kitesurfing]],

  # ---- APPAREL --------------------------------------------------------
  [/\bponcho\b/i,                                       [:ponchos, :apparel]],
  [/boardshort|\bshort\b.*board/i,                      [:boardshorts, :apparel]],
  [/\bcap\b|\bbeanie\b|\bhat\b/i,                       [:caps, :apparel]],
  [/\blycra\b|\blyc\b/i,                                [:lycra, :apparel]],
  [/nylon.*shirt|\bsurf.*shirt\b/i,                     [:nylon_shirts, :apparel]],
  [/sun.*protect|sun.*screen/i,                         [:sun_protection, :apparel]],
  [/\bcoat\b|\bjacket\b/i,                              [:coats, :apparel]],
  [/\btop\b|\bhoody\b|\bhoodie\b|\bfleece\b|\bt-shirt\b|\btshirt\b/i, [:tops, :apparel]],

  # ---- E-FOIL ---------------------------------------------------------
  [/e-?foil.*set|\bfliteboard\b|\bwaydoo\b|\blift.*efoil/i, [:efoil_sets, :efoil]],
  [/e-?foil|emast|e-?mast|epropeller|motor.*bell|motor.*pod|battery.*box|battery.*bag|battery.*7a|cruise.*battery|wire.*antenna/i, [:efoil_spare, :efoil]],

  # ---- KITE SPARE PARTS (Duotone, Cabrinha — bladers, bridles, lines) ---
  [/bladder.*(leading|strut|tip|middle|quarter|center|quart|front.*tube)/i, [:kite_spare, :kitesurfing]],
  [/bladder.*strut.*unit/i,                             [:kite_spare, :kitesurfing]],
  [/bridle.*set|bridle.*line|front.*bridle|back.*bridle|pigtail|back.*pigtail|front.*pigtail/i, [:kite_spare, :kitesurfing]],
  [/line.*set.*(bar|qc)|click.*bar|trust.*bar|bar.*(plain|small|medium|large)/i, [:kite_bars, :kitesurfing]],
  [/flying.*line|back.*line|front.*line|rear.*line|upper.*front.*line|lower.*front.*line|depower.*line|landing.*line/i, [:kite_spare, :kitesurfing]],
  [/relaunch.*bungee|noseline|bungee.*nose|bungee.*click|floater.*bar/i, [:kite_spare, :kitesurfing]],
  [/airlock.*valve|valve.*assembly|valve.*seal|valve.*socket|valve.*angled|valve.*straight/i, [:kite_spare, :kitesurfing]],
  [/dacron|tri-ply|odl.*sandwich|adhesive.*ripstop|adhesive.*markcloth|kite.*repair|repair.*tape/i, [:kite_spare, :kitesurfing]],
  [/safety.*leash.*kite|kite.*safety|short.*safety.*leash|neoprene.*safety.*leash/i, [:kite_spare, :kitesurfing]],
  [/\bstrut\b.*(kite|neo|evo|rebel|dice|juice|moto|mantis|apex|nitro|vision|aer|vapor)/i, [:kite_spare, :kitesurfing]],
  [/(kite|neo|evo|rebel|dice|juice|moto|mantis|apex|nitro|vapor).*\bstrut\b/i, [:kite_spare, :kitesurfing]],
  [/connector.*system|connector.*loop|connector.*pin|connector.*freestyle|surf.*slider/i, [:kite_spare, :kitesurfing]],
  [/bar.*bungee|winding.*post|sliding.*bar.*stopper|rubber.*plug.*bar|red.*safety.*line/i, [:kite_spare, :kitesurfing]],
  [/extension.*line.*set|click.*bar.*upgrade|hadlow.*upgrade|5th.*element.*upgrade/i, [:kite_spare, :kitesurfing]],
  [/iron.*heart|ratchet.*lever|power.*xt|double.*pin.*lock|entity.*strap|entity.*washer/i, [:kite_spare, :kitesurfing]],
  [/traction.*pad|vario.*pad|insert.*pad|\bpad\b.*(dlab|sls|insert)/i, [:kite_pads, :kitesurfing]],
  [/\bfin\b.*(ts-m|ts-s|inj.*mold|rtm|quad|thruster|screw|tt.*fin|surf.*fin)/i, [:kite_spare, :kitesurfing]],
  [/tt.*handle|track.*nut|ultralight.*strap|waist.*leash.*kite|unify.*leash|unify.*qr/i, [:kite_spare, :kitesurfing]],
  [/screw.*set.*tools|board.*spare.*kit|board.*spare.*multi|zipper.*teeth|zipper.*pouch/i, [:kite_spare, :kitesurfing]],
  [/duffel.*bag.*kite|roller.*bag.*kite|carry.*on.*bag|surf.*travel.*bag/i, [:kite_spare, :kitesurfing]],
  [/cabrinha.*(foam|code|bump|link|logic|mantis|moto|nitro|phantom|swift|switchblade|vapor|flare|drifter|h3|spirit)/i, [:kite_spare, :kitesurfing]],

  # ---- KITE BARS (standalone) ----------------------------------------
  [/trust.*bar.*quad|\bclick.*bar\b|\btrust.*bar\b|5th.*line.*pigtail|minimalistic.*pigtail/i, [:kite_bars, :kitesurfing]],

  # ---- HARNESS PARTS (ION) -------------------------------------------
  [/\bharn.*sp\b|\bharn\.sp\b|harness.*spare|harness.*seatpart|ergo.*pad|downforce.*loop|releasebuckle|carbine.*rope|lever.*buckle|webbing.*slider|safety.*leash.*d-ring|c-bar.*screw|spectre.*bar.*screw/i, [:harness_parts, :windsurf_harnesses, :windsurf]],
  [/hook.*windsurf|windsurf.*hook|windsurf.*aluminium.*hook|spreader.*bar/i,              [:harness_hooks, :windsurf_harnesses, :windsurf]],

  # ---- WINDSURF ACCESSORIES/PARTS (ION, Neilpryde, Duotone) ----------
  [/uphaul.*line|uphaul.*rope|\buphaul\b/i,             [:windsurf_spare, :windsurf]],
  [/mast.*base.*protector|mastbase.*protector|nose.*bumper.*windsurf|windsurf.*nose|board.*protector.*windsurf/i, [:windsurf_spare, :windsurf]],
  [/windsurf.*seat|seat.*windsurf|windsurf.*harness.*seat|windsurf.*octane|windsurf.*radium/i, [:windsurf_harnesses, :windsurf]],
  [/windsurf.*waist|waist.*windsurf/i,                  [:windsurf_harnesses, :windsurf]],
  [/\brdm\b|\bsdm\b|x100.*pro|x75.*rdm|spx.*sdm|dragonfly.*rdm|mxt.*rdm|mxt.*sdm|uxt.*rdm|uxt.*sdm/i, [:windsurf_masts, :windsurf]],
  [/rdm.*extension|sdm.*extension|mxt.*extension|uxt.*extension|x-tender|deep.*tuttle.*adapter|power.*box.*adapter|power.*mxt.*base|power.*uxt.*base|surfplate.*adapter/i, [:windsurf_extensions, :windsurf]],
  [/neilpryde.*gravity|neilpryde.*evo.*harness|neilpryde.*s1.*ez/i,                       [:windsurf_harnesses, :windsurf]],
  [/performer.*boardbag|windsurf.*boardbag|boardbag.*windsurf/i,                          [:windsurf_bags, :windsurf]],
  [/neilpryde.*thermabase/i,                            [:wetsuit_2mm_men, :men_wetsuits, :wetsuits]],
  [/solid.*batten|single.*batten|batten.*replacement/i, [:windsurf_spare, :windsurf]],
  [/\bfin\b.*(fanatic|windsurf|jag)|fanatic.*fin|\btuttle\b/i, [:windsurf_fins, :windsurf]],

  # ---- WINDSURF BOARDS (Tabou, Fanatic) -------------------------------
  [/tabou|fanatic.*(windsurf|wave|freeride|freestyle|slalom|speed)|air.*ride|rocket.*plus|super.*yaka|manta.*foil/i, [:windsurf_boards, :windsurf]],
  [/downwinder|falcon.*fin|falcon.*speed|crush.*sls|skate.*sls|sky.*style|blur.*sls|select.*concept|volt.*dlab|volt.*sls/i, [:windsurf_boards, :windsurf]],

  # ---- ION BAGS & ACCESSORIES -----------------------------------------
  [/blade.*bag|gearbag.*tec|session.*bag|session.*duffel|suspect.*duffel|carry.*on.*wheelie|mission.*backpack|explorer.*bag/i, [:windsurf_bags, :windsurf]],
  [/surf.*boardbag|surf.*sock|wake.*boardbag|surf.*leash|surf.*bag/i,                     [:kite_surf_boards, :kitesurfing]],
  [/\bboardbag\b|\bboard.*bag\b/i,                      [:windsurf_bags, :windsurf]],

  # ---- ION APPAREL/LIFESTYLE ------------------------------------------
  [/\bponcho\b|\bchanging.*bucket\b|\bchanging.*mat\b|\bwetbag\b|\bdry.*bag\b|\bbeach.*towel\b|\bseat.*towel\b/i, [:ponchos, :apparel]],
  [/\btee\b|\bt-shirt\b|\bsweater\b|\bhoodie\b|\bhoody\b|\bfleece\b|\bshirt\b.*ionic|\bshirt\b.*denim/i, [:tops, :apparel]],
  [/\bshorts\b.*denim|\bshorts\b.*cotton|\bshorts\b.*hd|\bpants\b.*denim|\bpants\b.*cotton|\bpants\b.*hd/i, [:boardshorts, :apparel]],
  [/ball.*slapper.*shorts|\bbottom.*tights\b|\bbottom.*shorts\b|\bbottom.*base\b/i,       [:boardshorts, :apparel]],
  [/\bsocks\b.*ionic|\bsocks\b.*long/i,                 [:neo_accessories, :wetsuits]],
  [/plasma.*slipper|plasma.*socks|ballistic.*toes|bandit.*gaiter|open.*palm.*mitten/i,    [:shoes, :neo_accessories, :wetsuits]],
  [/long.*john|monoshorty|neo.*pants|neo.*shorts|wetshirt|seek.*core|long.*jane/i,        [:men_wetsuits, :wetsuits]],

  # ---- ION HARNESS PRODUCTS -------------------------------------------
  [/\briot\b|\bapex\b|\barc\b|\baxxis\b|\bb2\b|\becho\b|\bfuel\b|\bicon\b|\bjade\b|\bjewel\b|\bmuse\b|\bnova\b|\boctane\b|\bradar\b|\bradium\b|\brave\b|\brail.*lover\b|\bripper\b|\brival\b|\brogue\b|\brush\b|\bsol\b|\bsonar\b|\bspectre\b|\bvega\b/i, [:kite_harnesses, :kitesurfing]],
  [/hip.*belt|foot.*protector|\bfootstrap\b|safety.*footstrap|v-footstrap/i,              [:kite_spare, :kitesurfing]],

  # ---- ION KITE ACCESSORIES -------------------------------------------
  [/handle.*pass.*leash|surf.*ring.*harness|roof.*rack|roof.*strap|car.*rack/i,           [:kite_spare, :kitesurfing]],
  [/connector.*loop.*spectre|flaps.*spectre|pad.*spectre|repl.*webbing.*spectre|washer.*set.*spectre/i, [:harness_parts, :windsurf_harnesses, :windsurf]],

  # ---- SUN PROTECTION -------------------------------------------------
  [/island.*tribe|spf.*lip|spf.*lotion|sunscreen|sun.*cream/i,                           [:sun_protection, :apparel]],

  # ---- E-FOIL ---------------------------------------------------------
  [/e-?foil.*set|\bfliteboard\b|\bwaydoo\b|\blift.*efoil/i, [:efoil_sets, :efoil]],
  [/e-?foil/i,                                          [:efoil_spare, :efoil]],
].freeze

# -----------------------------------------------------------------------
# Find uncategorized products and apply rules
# -----------------------------------------------------------------------
cats_taxonomy   = Spree::Taxonomy.find_by(name: 'Categories')
cat_taxon_ids   = Spree::Taxon.where(taxonomy: cats_taxonomy).pluck(:id)

# Products with no category at all
uncategorized = Spree::Product.active
  .left_joins(:taxons)
  .where('spree_taxons.id IS NULL OR spree_products.id NOT IN (
    SELECT DISTINCT stp.product_id FROM spree_products_taxons stp
    WHERE stp.taxon_id IN (' + cat_taxon_ids.join(',') + ')
  )')
  .distinct

total         = uncategorized.count
puts "Uncategorized products: #{total}"

categorized   = 0
unmatched     = 0
unmatched_names = []

uncategorized.find_each do |product|
  name = product.name

  match = RULES.find { |pattern, _| name.match?(pattern) }

  if match
    _, taxon_keys = match
    to_add = taxon_keys.map { |k| @taxons[T[k]] }.compact - product.taxons.to_a
    product.taxons << to_add unless to_add.empty?
    categorized += 1
  else
    unmatched += 1
    unmatched_names << name
  end
end

puts "\n#{'='*60}"
puts "Categorized : #{categorized}"
puts "Unmatched   : #{unmatched}"

if unmatched_names.any?
  puts "\nUnmatched products (need manual review):"
  unmatched_names.sort.each { |n| puts "  #{n}" }
end
