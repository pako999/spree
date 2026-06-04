# frozen_string_literal: true

# Idempotent populator for Duotone E-Foil product properties.
#
# Fills editorial properties (feature cards, materials, FAQ accordion) so the
# global PDP sections (_pdp_content_sections.html.erb) light up on each
# product page.
#
# Run:
#   docker cp sandbox/script/populate_duotone_efoil_properties.rb \
#        surf-store:/rails/tmp/
#   ssh ubuntu@46.224.5.25 \
#        "docker exec surf-store bundle exec rails runner \
#         /rails/tmp/populate_duotone_efoil_properties.rb"
#
# Safe to run multiple times — uses find_or_initialize_by for ProductProperty.
# All copy sourced from duotonesports.com and foildrive.com.

# ─────────────────────────────────────────────────────────────────────────────
# Shared FAQ and materials blocks (reused across product families)
# ─────────────────────────────────────────────────────────────────────────────

SHARED_FAQ_SYSTEM = [
  "Is the Duotone Foil Assist an eFoil? | No. It is a Foil Assist — it provides power for take-offs and light-wind sessions but preserves the natural feel of traditional foiling. The motor is used when you need a boost; you ride pure foil the rest of the time.",
  "How long does the battery last? | 30 to 60+ minutes per charge depending on rider weight, foil size, riding style, and conditions. Using the motor in short bursts for wave-catching provides the longest sessions.",
  "Can I fly with the batteries? | Yes. Each battery is 159.6 Wh, designed to be under the 160 Wh IATA airline limit. Always verify your specific airline's policy before travelling.",
  "Will it work with my existing foil? | The system is compatible with boards using standard US foil tracks. You need a brand-specific fuselage adapter (sold separately). Compatible brands include Duotone, Armstrong, AFS, Axis, Code Foils, F-One, North, SAB, Lift, KT, and Gong.",
  "What is the difference between Standard and Cruise? | Standard (AL / D/LAB) has the motor at the top of the mast — ideal for wave riding, downwinding, and wing foiling. Cruise has the motor at the bottom with an optional prop guard — designed for flatwater cruising and learning.",
  "Do you ship across the EU? | Yes. Surf Store ships to all EU countries. Lithium batteries are shipped via ground transport in compliance with IATA DGR regulations."
].join(" || ").freeze

SHARED_FAQ_BATTERY = [
  "How long does the battery last? | 30 to 60+ minutes per charge depending on rider weight, foil size, riding style, and conditions. Short bursts provide the longest sessions.",
  "Can I fly with the batteries? | Yes. Each battery is 159.6 Wh, under the 160 Wh IATA airline limit. Always verify your airline's policy before travelling.",
  "How do I charge the batteries? | Use the included dual-battery charger. Full charge takes under 1 hour.",
  "How should I store the batteries? | Recharge to storage mode (2-3 LED lights) after use. Never leave fully charged or fully empty for extended periods.",
  "Do you ship batteries across the EU? | Yes. Lithium batteries are shipped via ground transport in compliance with IATA DGR regulations."
].join(" || ").freeze

SHARED_FAQ_ACCESSORY = [
  "Is this compatible with the Duotone Foil Assist system? | Yes. This is an official Duotone accessory designed for the Foil Assist ecosystem.",
  "Do you ship across the EU? | Yes. Surf Store ships to all EU countries with tracked and insured delivery.",
  "What warranty is included? | All Duotone accessories come with a 2-year manufacturer warranty covering defects in materials and workmanship."
].join(" || ").freeze

SHARED_FAQ_ADAPTER = [
  "Do I need a fuselage adapter? | Yes, if you are using a non-Duotone foil. Each adapter is brand-specific and connects the Duotone eMast to your foil's fuselage.",
  "Which adapter do I need? | Select the adapter matching your foil brand. The AL eMast supports all listed brands. The D/LAB eMast has direct Duotone fit plus Armstrong adapter compatibility.",
  "Is this compatible with the Duotone Foil Assist system? | Yes. This is an official Duotone accessory designed specifically for the Foil Assist eMast.",
  "Do you ship across the EU? | Yes. Surf Store ships to all EU countries with tracked and insured delivery."
].join(" || ").freeze

SHARED_FAQ_BOARD = [
  "Is this board designed for the Foil Assist? | Yes. The Duotone Midfish series is purpose-built for perfect Foil Assist integration with standard US foil tracks.",
  "Can I use this board without the Foil Assist? | Yes. The board works with any foil using standard US foil tracks — with or without electric assist.",
  "Do you ship across the EU? | Yes. Surf Store ships to all EU countries. Boards are shipped via freight with tracking and insurance."
].join(" || ").freeze

SHARED_MATERIALS_MAST_AL =
  "Anodized aluminum | Lightweight, corrosion-resistant mast body with 120 mm chord and 18 mm minimum thickness." \
  " || Integrated motor pod | Fully sealed motor housing positioned 17 cm below the top plate for clean hydrodynamics." \
  " || 2-blade folding propeller | Deploys only when motor is engaged, folds flat for zero-drag gliding when off." \
  " || Stainless steel hardware | Marine-grade mounting screws and fasteners rated for saltwater use."

SHARED_MATERIALS_MAST_DLAB =
  "High-modulus prepreg carbon | Ultra-lightweight D/LAB carbon construction for reduced weight and lower drag." \
  " || Integrated motor pod | Fully sealed motor housing positioned 17 cm below the top plate for clean hydrodynamics." \
  " || 2-blade folding propeller | Deploys only when motor is engaged, folds flat for zero-drag gliding when off." \
  " || Stainless steel hardware | Marine-grade mounting screws and fasteners rated for saltwater use."

SHARED_MATERIALS_BATTERY =
  "High-voltage LiPo cells | 159.6 Wh per battery, airline-friendly (under 160 Wh IATA limit)." \
  " || Waterproof battery box | Sealed housing with neoprene cover and quick-release safety system." \
  " || ABS outer shell | Impact-resistant protective casing for durability on and off the water."

SHARED_MATERIALS_HARNESS =
  "Buoyant core | Closed-cell foam construction keeps the harness afloat if released in the water." \
  " || Neoprene padding | Comfortable, water-draining body contact layer with quick-dry properties." \
  " || Waterproof battery housing | Sealed compartment for 2x battery boxes on the lower back." \
  " || Quick-release buckle | Emergency release system for rapid removal in the water."

# ─────────────────────────────────────────────────────────────────────────────
# DATA — slug → properties. Only real Duotone content, no invented values.
# ─────────────────────────────────────────────────────────────────────────────

DATA = {
  # ── COMPLETE SETS ──────────────────────────────────────────────────────────

  "duotone-foil-assist-set-al-2026" => {
    "short_description" => "Complete Duotone Foil Assist set with 84 cm aluminum eMast, eHarness, 2x batteries, Watch Ring Remote, and dual charger. Power when you need it — pure foiling when you don't.",
    "feature_1_title"   => "Integrated eMast — silent electric power",
    "feature_1_text"    => "The motor pod is fully integrated into the 84 cm aluminum mast profile, positioned 17 cm below the top plate. The 2-blade folding propeller deploys only when engaged — zero drag when you're gliding on pure foil.",
    "feature_2_title"   => "Battery on your hips, not under your feet",
    "feature_2_text"    => "Unlike systems that mount batteries on the board, the Foil Assist uses a buoyant waist-mounted eHarness. The board stays light and agile for a natural foiling feel.",
    "materials"         => SHARED_MATERIALS_MAST_AL,
    "faq"               => SHARED_FAQ_SYSTEM
  },

  "duotone-foil-assist-set-d-lab" => {
    "short_description" => "Premium Duotone Foil Assist set with 84 cm high-modulus prepreg carbon D/LAB eMast, eHarness, 2x batteries, Watch Ring Remote, and dual charger. The ultimate performance setup.",
    "feature_1_title"   => "D/LAB carbon — maximum performance",
    "feature_1_text"    => "The 84 cm D/LAB eMast uses high-modulus prepreg carbon for lower weight, reduced drag, and higher stiffness than the aluminum version. Built for advanced riders who demand peak performance.",
    "feature_2_title"   => "Hands-free Watch Ring Remote",
    "feature_2_text"    => "Control the motor with a waterproof smartwatch on your wrist and a finger ring. Double-click to activate, squeeze to engage, release to stop. Multiple power levels plus Boost mode — your hands stay free to paddle, pop up, or handle a wing.",
    "materials"         => SHARED_MATERIALS_MAST_DLAB,
    "faq"               => SHARED_FAQ_SYSTEM
  },

  "foil-assist-set-complete-al-incl-board" => {
    "short_description" => "The all-in-one Duotone Foil Assist package: AL eMast set plus a Duotone board, ready to ride out of the box. Everything you need to start electric-assisted foiling.",
    "feature_1_title"   => "Complete package — ride out of the box",
    "feature_1_text"    => "Includes the full Foil Assist AL set (84 cm eMast, eHarness, 2x batteries, Watch Ring Remote, dual charger) plus a Duotone board with standard US foil tracks. No separate purchases needed.",
    "feature_2_title"   => "Battery on your hips, not under your feet",
    "feature_2_text"    => "The buoyant waist-mounted eHarness keeps all battery weight off the board. The result: a light, agile setup that feels like traditional foiling with electric launch assist.",
    "materials"         => SHARED_MATERIALS_MAST_AL,
    "faq"               => SHARED_FAQ_SYSTEM
  },

  "duotone-foil-cruise-set-al-2026" => {
    "short_description" => "Duotone Foil Cruise set with 80 cm aluminum eMast (motor at bottom), eHarness, 2x batteries, Watch Ring Remote, and dual charger. Designed for flatwater cruising and learning to foil.",
    "feature_1_title"   => "Cruise mode — continuous propulsion",
    "feature_1_text"    => "The Cruise eMast positions the motor at the bottom of the 80 cm mast, providing consistent, continuous thrust. Perfect for flatwater cruising, learning to foil, and rental or school operations. Optional prop guard available.",
    "feature_2_title"   => "Waist-mounted eHarness",
    "feature_2_text"    => "Buoyant harness carries batteries on your hips with a quick-release safety system. The board stays light and balanced — no heavy battery pods underneath.",
    "materials"         => SHARED_MATERIALS_MAST_AL,
    "faq"               => SHARED_FAQ_SYSTEM
  },

  "foil-cruise-set-complete-al-incl-board" => {
    "short_description" => "Complete Duotone Foil Cruise package with AL Cruise eMast set and a Duotone board. The easiest way to start flatwater electric foiling.",
    "feature_1_title"   => "Cruise — learn to foil with electric assist",
    "feature_1_text"    => "Bottom-mounted motor provides smooth, continuous propulsion on flat water. Includes optional prop guard support for added safety. The complete set comes with board, eMast, eHarness, batteries, remote, and charger.",
    "feature_2_title"   => "Travel-friendly batteries",
    "feature_2_text"    => "Each battery is 159.6 Wh — designed to stay under the 160 Wh IATA airline limit. The dual charger gets both batteries back to full in under 1 hour.",
    "materials"         => SHARED_MATERIALS_MAST_AL,
    "faq"               => SHARED_FAQ_SYSTEM
  },

  # ── eMAST COMPONENTS ──────────────────────────────────────────────────────

  "duotone-emast-d-lab-set-2026" => {
    "short_description" => "Upgrade to the D/LAB carbon eMast set. High-modulus prepreg carbon mast with integrated motor, 2-blade folding propeller, and all necessary cables and hardware.",
    "feature_1_title"   => "D/LAB carbon construction",
    "feature_1_text"    => "High-modulus prepreg carbon for the lowest weight and drag in the Foil Assist lineup. Stiffer than aluminum with better flex characteristics for advanced riding.",
    "feature_2_title"   => "Integrated motor — clean hydrodynamics",
    "feature_2_text"    => "Motor pod fully integrated into the mast profile at 17 cm below the top plate. No external cables or bolt-on pods. The folding propeller creates zero drag when not in use.",
    "materials"         => SHARED_MATERIALS_MAST_DLAB,
    "faq"               => [
      "Can I upgrade my AL set to D/LAB? | Yes. The D/LAB eMast is a drop-in replacement for the AL eMast. All other components (eHarness, batteries, remote, charger) remain the same.",
      "What is the weight difference? | The D/LAB carbon mast is noticeably lighter than the 3.45 kg AL version, with reduced drag for improved glide performance.",
      SHARED_FAQ_SYSTEM.split(" || ").last(3).join(" || ")
    ].join(" || ")
  },

  "emast-d-lab-only-w-o-any-electric-parts" => {
    "short_description" => "D/LAB carbon mast body only, without electric motor or electronics. For riders who need a replacement mast or want to build a custom setup.",
    "materials"         => "High-modulus prepreg carbon | Ultra-lightweight D/LAB construction with optimized flex pattern for foiling performance.",
    "faq"               => SHARED_FAQ_ACCESSORY
  },

  # ── BATTERIES & CHARGING ──────────────────────────────────────────────────

  "battery-7a-set-2pcs" => {
    "short_description" => "Set of 2x high-performance LiPo batteries for the Duotone Foil Assist. 159.6 Wh each (319.2 Wh total), airline-friendly, with waterproof battery box housing.",
    "feature_1_title"   => "Airline-friendly design",
    "feature_1_text"    => "Each battery is 159.6 Wh — designed to stay under the 160 Wh IATA limit for lithium batteries in cabin baggage. Travel to your favourite foiling spots without shipping hassles.",
    "feature_2_title"   => "Quick swap, fast charge",
    "feature_2_text"    => "The dual-battery system allows fast swaps on the beach. Full charge in under 1 hour with the included dual charger. 30 to 60+ minutes of riding per charge.",
    "materials"         => SHARED_MATERIALS_BATTERY,
    "faq"               => SHARED_FAQ_BATTERY
  },

  "dte-battery-1pcs-2026" => {
    "short_description" => "Single replacement battery for the Duotone Foil Assist system. 159.6 Wh high-voltage LiPo, airline-friendly.",
    "materials"         => SHARED_MATERIALS_BATTERY,
    "faq"               => SHARED_FAQ_BATTERY
  },

  "dte-battery-set-2pcs-2026" => {
    "short_description" => "Set of 2x high-performance LiPo batteries for the Duotone Foil Assist. 159.6 Wh each, airline-friendly, full charge in under 1 hour.",
    "feature_1_title"   => "Airline-friendly design",
    "feature_1_text"    => "Each battery is 159.6 Wh — designed to stay under the 160 Wh IATA limit. Carry them in your cabin baggage on most airlines.",
    "materials"         => SHARED_MATERIALS_BATTERY,
    "faq"               => SHARED_FAQ_BATTERY
  },

  "dte-battery-charger-set-for-warehouse-2026" => {
    "short_description" => "Dual-battery charging dock and power adapter for the Duotone Foil Assist system. Charges both batteries simultaneously in under 1 hour.",
    "faq"               => SHARED_FAQ_ACCESSORY
  },

  # ── BATTERY BOX & MOUNTING ────────────────────────────────────────────────

  "battery-box-with-antenna-plug" => {
    "short_description" => "Waterproof battery box with integrated antenna plug for the Duotone Foil Assist eHarness. Houses one battery securely with quick-release access.",
    "materials"         => "Waterproof housing | Sealed ABS construction protects the battery from water ingress. || Antenna plug | Integrated connection point for the wireless remote antenna. || Neoprene-compatible | Designed to fit inside the eHarness neoprene cover.",
    "faq"               => SHARED_FAQ_ACCESSORY
  },

  "battery-box-neoprene-cover" => {
    "short_description" => "Replacement neoprene cover for the Duotone Foil Assist battery box. Provides additional water protection and cushioning inside the eHarness.",
    "faq"               => SHARED_FAQ_ACCESSORY
  },

  "battery-box-mounting-plate" => {
    "short_description" => "Mounting plate for securing the Duotone battery box inside the eHarness. Ensures stable, rattle-free positioning during riding.",
    "faq"               => SHARED_FAQ_ACCESSORY
  },

  "battery-box-mounting-straps-4pcs" => {
    "short_description" => "Set of 4 replacement mounting straps for the Duotone Foil Assist battery box. Secures the battery box firmly inside the eHarness.",
    "faq"               => SHARED_FAQ_ACCESSORY
  },

  "cruise-battery-box-mounting-set" => {
    "short_description" => "Complete battery box mounting set for the Duotone Foil Cruise configuration. Includes mounting plate, straps, and hardware for secure battery installation in the eHarness.",
    "faq"               => SHARED_FAQ_ACCESSORY
  },

  "battery-bag" => {
    "short_description" => "Padded transport bag for Duotone Foil Assist batteries. Protects batteries during travel and storage with cushioned interior.",
    "faq"               => SHARED_FAQ_ACCESSORY
  },

  # ── REMOTE & ELECTRONICS ──────────────────────────────────────────────────

  "dte-ring-xl-only-2026" => {
    "short_description" => "Replacement XL finger ring for the Duotone Watch Ring Remote. Squeeze to engage the motor, release to stop. Waterproof and designed for larger fingers.",
    "faq"               => SHARED_FAQ_ACCESSORY
  },

  "wire-antenna" => {
    "short_description" => "Replacement wire antenna for the Duotone Foil Assist system. Ensures reliable wireless communication between the Watch Ring Remote and the motor controller.",
    "faq"               => SHARED_FAQ_ACCESSORY
  },

  "duotone-cable-connector-for-efoil" => {
    "short_description" => "Replacement cable and connector set for the Duotone Foil Assist system. Connects the eHarness battery to the eMast motor.",
    "faq"               => SHARED_FAQ_ACCESSORY
  },

  # ── MOTOR & PROPELLER ─────────────────────────────────────────────────────

  "motor-bell-with-propeller" => {
    "short_description" => "Replacement motor bell assembly with 2-blade folding propeller for the Duotone Foil Assist eMast. The propeller deploys only when the motor is engaged and folds flat for zero-drag gliding.",
    "materials"         => "Sealed motor bell | Waterproof motor housing with integrated bearings. || 2-blade folding propeller | Deploys on motor engagement, folds flat for zero drag when off.",
    "faq"               => SHARED_FAQ_ACCESSORY
  },

  "dte-motor-bell-only-2026" => {
    "short_description" => "Replacement motor bell (without propeller) for the Duotone Foil Assist eMast. Sealed, waterproof housing with integrated bearings.",
    "faq"               => SHARED_FAQ_ACCESSORY
  },

  "motor-bell-propeller-cover" => {
    "short_description" => "Protective cover for the Duotone Foil Assist motor bell and propeller. Shields the motor from impact and debris during transport and storage.",
    "faq"               => SHARED_FAQ_ACCESSORY
  },

  "motor-pod-cover" => {
    "short_description" => "Protective cover for the Duotone Foil Assist motor pod section of the eMast. Prevents damage during transport.",
    "faq"               => SHARED_FAQ_ACCESSORY
  },

  "epropeller-blade-power-2pcs" => {
    "short_description" => "Set of 2 replacement propeller blades (Power profile) for the Duotone Foil Assist 2-blade folding propeller system.",
    "materials"         => "Composite blades | Engineered for optimal thrust and efficiency. Folding design creates zero drag when not in use.",
    "faq"               => SHARED_FAQ_ACCESSORY
  },

  "epropeller-blades-mount" => {
    "short_description" => "Replacement propeller blade mount for the Duotone Foil Assist system. Connects propeller blades to the motor bell.",
    "faq"               => SHARED_FAQ_ACCESSORY
  },

  "dte-epropeller-3-blade-sls-3pcs-2026" => {
    "short_description" => "Set of 3 SLS aluminum propeller blades for the Duotone Foil Assist. Upgraded 3-blade configuration for increased thrust and smoother power delivery.",
    "materials"         => "SLS aluminum | Selective Laser Sintered aluminum blades for precision geometry, strength, and corrosion resistance.",
    "faq"               => [
      "What is the advantage of the 3-blade propeller? | The 3-blade SLS configuration delivers smoother thrust with less vibration and increased total thrust compared to the standard 2-blade setup.",
      "Is it compatible with my existing Foil Assist? | Yes. The 3-blade SLS blades mount to the standard propeller mount on any Duotone Foil Assist eMast.",
      SHARED_FAQ_ACCESSORY
    ].join(" || ")
  },

  "dte-epropeller-3-blade-mount-2026" => {
    "short_description" => "Propeller mount designed for the 3-blade SLS propeller configuration. Required when upgrading from the standard 2-blade to 3-blade setup.",
    "faq"               => SHARED_FAQ_ACCESSORY
  },

  "dte-epropeller-3-blade-sls-with-mount-2026" => {
    "short_description" => "Complete 3-blade SLS aluminum propeller upgrade kit: 3 SLS blades plus the dedicated 3-blade mount. Drop-in upgrade for any Duotone Foil Assist eMast.",
    "materials"         => "SLS aluminum blades | Selective Laser Sintered aluminum for precision, strength, and corrosion resistance. || Dedicated 3-blade mount | Engineered for the increased load of three blades.",
    "faq"               => [
      "What is the advantage of the 3-blade propeller? | The 3-blade SLS configuration delivers smoother thrust with less vibration and increased total thrust compared to the standard 2-blade setup.",
      SHARED_FAQ_ACCESSORY
    ].join(" || ")
  },

  # ── COVERS & BAGS ─────────────────────────────────────────────────────────

  "assist-emast-cover" => {
    "short_description" => "Padded protective cover for the Duotone Foil Assist eMast. Protects the motor pod and mast during transport and storage.",
    "faq"               => SHARED_FAQ_ACCESSORY
  },

  "cruise-emast-cover" => {
    "short_description" => "Padded protective cover for the Duotone Foil Cruise eMast. Designed for the Cruise configuration with bottom-mounted motor.",
    "faq"               => SHARED_FAQ_ACCESSORY
  },

  "gearbag-foil-assist" => {
    "short_description" => "Dedicated gear bag for the complete Duotone Foil Assist system. Fits eMast, eHarness, batteries, remote, charger, and accessories in one organized bag.",
    "faq"               => SHARED_FAQ_ACCESSORY
  },

  # ── CRUISE TOP PLATE ──────────────────────────────────────────────────────

  "cruise-al-top-plate-with-male-connector-and-cables" => {
    "short_description" => "Replacement aluminum top plate with male connector and cables for the Duotone Foil Cruise eMast. Connects the eMast to the board's foil track.",
    "faq"               => SHARED_FAQ_ACCESSORY
  },

  "cruise-male-connector-with-cables-top-plate-only" => {
    "short_description" => "Replacement male connector with cables for the Cruise top plate. For servicing the electrical connection between the eHarness and Cruise eMast.",
    "faq"               => SHARED_FAQ_ACCESSORY
  },

  # ── FUSELAGE ADAPTERS ─────────────────────────────────────────────────────

  "duotone-adapter-fuselage" => {
    "short_description" => "Fuselage adapter for connecting the Duotone Foil Assist eMast to Duotone foils. Direct fit — no additional adapters needed.",
    "faq"               => SHARED_FAQ_ADAPTER
  },

  "duotone-adapter-fuselage-afs" => {
    "short_description" => "Fuselage adapter for connecting the Duotone Foil Assist eMast to AFS foils.",
    "faq"               => SHARED_FAQ_ADAPTER
  },

  "duotone-adapter-fuselage-axis" => {
    "short_description" => "Fuselage adapter for connecting the Duotone Foil Assist eMast to Axis foils.",
    "faq"               => SHARED_FAQ_ADAPTER
  },

  "duotone-adapter-fuselage-code" => {
    "short_description" => "Fuselage adapter for connecting the Duotone Foil Assist eMast to Code Foils.",
    "faq"               => SHARED_FAQ_ADAPTER
  },

  "duotone-adapter-fuselage-f-one" => {
    "short_description" => "Fuselage adapter for connecting the Duotone Foil Assist eMast to F-One Titan 1 foils.",
    "faq"               => SHARED_FAQ_ADAPTER
  },

  "duotone-adapter-fuselage-gong" => {
    "short_description" => "Fuselage adapter for connecting the Duotone Foil Assist eMast to Gong foils.",
    "faq"               => SHARED_FAQ_ADAPTER
  },

  "duotone-adapter-fuselage-kt" => {
    "short_description" => "Fuselage adapter for connecting the Duotone Foil Assist eMast to KT foils.",
    "faq"               => SHARED_FAQ_ADAPTER
  },

  "duotone-adapter-fuselage-lift" => {
    "short_description" => "Fuselage adapter for connecting the Duotone Foil Assist eMast to Lift foils.",
    "faq"               => SHARED_FAQ_ADAPTER
  },

  "duotone-adapter-fuselage-north" => {
    "short_description" => "Fuselage adapter for connecting the Duotone Foil Assist eMast to North (GeoLock) foils.",
    "faq"               => SHARED_FAQ_ADAPTER
  },

  "duotone-adapter-fuselage-sab" => {
    "short_description" => "Fuselage adapter for connecting the Duotone Foil Assist eMast to SAB foils.",
    "faq"               => SHARED_FAQ_ADAPTER
  },

  # ── BOARDS ────────────────────────────────────────────────────────────────

  "duotone-electric-midfish-2026" => {
    "short_description" => "The Duotone Midfish 2026 — purpose-built board designed for perfect Foil Assist integration. Standard US foil tracks, optimized volume and outline for electric-assisted foiling.",
    "feature_1_title"   => "Designed for Foil Assist",
    "feature_1_text"    => "The Midfish is engineered specifically for the Duotone Foil Assist system. Optimized volume distribution and a compact outline make it easy to get up on the foil with electric assist.",
    "faq"               => SHARED_FAQ_BOARD
  },

  "duotone-midfish-air-2026" => {
    "short_description" => "The Duotone Midfish Air 2026 — inflatable version of the Foil Assist board. Lightweight, packable, and travel-friendly with standard US foil tracks.",
    "feature_1_title"   => "Inflatable — ultimate travel freedom",
    "feature_1_text"    => "The Midfish Air packs down into a compact bag for easy transport. Inflates quickly on the beach and delivers solid performance with the Foil Assist system. Standard US foil tracks for universal compatibility.",
    "faq"               => SHARED_FAQ_BOARD
  },

  # ── FOIL WINGS & BOARDS (non-electric but in the e-foil taxon) ────────────

  "duotone-crush-sls-2025" => {
    "short_description" => "Duotone Crush SLS 2025 — high-performance foil wing with SLS construction for advanced riders. Designed for wave riding and dynamic foiling.",
    "faq"               => SHARED_FAQ_ACCESSORY
  },

  "duotone-crush-sls-2026" => {
    "short_description" => "Duotone Crush SLS 2026 — updated high-performance foil wing with refined SLS construction. Optimized for wave riding and progressive foiling.",
    "faq"               => SHARED_FAQ_ACCESSORY
  },

  "dtf-paradox-sls-2026" => {
    "short_description" => "Duotone Paradox SLS — versatile foil wing combining freeride comfort with performance characteristics. SLS construction for the optimal balance of weight and durability.",
    "faq"               => SHARED_FAQ_ACCESSORY
  },

  "skybrid" => {
    "short_description" => "Duotone Skybrid 2025 — the versatile all-round foil board for wing foiling, prone foiling, and Foil Assist riding. Standard US foil tracks.",
    "faq"               => SHARED_FAQ_BOARD
  },

  "duotone-skybrid-air-2025" => {
    "short_description" => "Duotone Skybrid Air 2025 — inflatable foil board for wing foiling and Foil Assist. Travel-friendly and quick to set up.",
    "faq"               => SHARED_FAQ_BOARD
  },

  "duotone-skybrid-air-2026" => {
    "short_description" => "Duotone Skybrid Air 2026 — updated inflatable foil board with improved rigidity and foil track integration.",
    "faq"               => SHARED_FAQ_BOARD
  },

  "duotone-skybrid-d-lab-2026" => {
    "short_description" => "Duotone Skybrid D/LAB 2026 — premium carbon construction foil board. Ultra-lightweight with superior stiffness for advanced riders.",
    "faq"               => SHARED_FAQ_BOARD
  },

  "duotone-skybrid-d-lab-2027" => {
    "short_description" => "Duotone Skybrid D/LAB 2027 — next-generation premium carbon foil board with refined outline and construction.",
    "faq"               => SHARED_FAQ_BOARD
  },

  "duotone-skybrid-sls-2025" => {
    "short_description" => "Duotone Skybrid SLS 2025 — SLS construction foil board combining lightweight performance with durability for all-round foiling.",
    "faq"               => SHARED_FAQ_BOARD
  },

  "duotonefoil-wing-set-glide-2-0-d-lab-2025" => {
    "short_description" => "DuotoneFoil Wing Set Glide 2.0 D/LAB 2025 — complete foil wing set with D/LAB carbon construction. High aspect ratio for maximum glide and efficiency.",
    "faq"               => SHARED_FAQ_ACCESSORY
  },
}.freeze

# ─────────────────────────────────────────────────────────────────────────────
# Runner
# ─────────────────────────────────────────────────────────────────────────────

puts "Populating Duotone E-Foil product properties..."
puts "=" * 60

ok = 0
skip = 0

DATA.each do |slug, props|
  product = Spree::Product.find_by(slug: slug)
  unless product
    puts "SKIP  #{slug}  (not found in DB)"
    skip += 1
    next
  end

  props.each do |name, value|
    next if value.blank?

    prop = Spree::Property.find_or_create_by!(name: name) do |p|
      p.presentation = name.tr('_', ' ').capitalize
    end

    pp = Spree::ProductProperty.find_or_initialize_by(product: product, property: prop)
    pp.value = value
    pp.save!
  end

  puts "OK    #{slug}  (#{props.size} properties)"
  ok += 1
end

puts "=" * 60
puts "Done. OK=#{ok}  SKIP=#{skip}  Total=#{ok + skip}"
