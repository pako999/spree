module BrandLogoHelper
  # Maps downcased brand taxon names to real logo files in /public/brand-logos/.
  # NOTE: brand_logo_path_for strips invisible unicode before lookup so keys are plain ASCII.
  BRAND_LOGO_MAP = {
    # Duotone
    "duotone"                                 => "/brand-logos/duotone.webp",
    "duotone kiteboarding"                    => "/brand-logos/duotone-kiteboarding.webp",
    "duotone windsurfing"                     => "/brand-logos/duotone-windsurfing.webp",
    "duotone wing foiling"                    => "/brand-logos/duotone-wing-foiling.webp",
    "duotone wing"                            => "/brand-logos/duotone.webp",
    "duotone sup"                             => "/brand-logos/duotone.webp",
    "duotone apparel"                         => "/brand-logos/duotone-apparel.webp",
    "duotone foiling & electric"              => "/brand-logos/duotone.webp",
    "duotone foilwing"                        => "/brand-logos/duotone.webp",
    "duotone kite bars"                       => "/brand-logos/duotone-kiteboarding.webp",
    "duotone kite bags"                       => "/brand-logos/duotone-kiteboarding.webp",
    "duotone kite foils"                      => "/brand-logos/duotone-kiteboarding.webp",
    "duotone kiteboards"                      => "/brand-logos/duotone-kiteboarding.webp",
    "duotone kites"                           => "/brand-logos/duotone-kiteboarding.webp",
    "duotone kite harnesses"                  => "/brand-logos/duotone-kiteboarding.webp",
    "duotone pads & straps"                   => "/brand-logos/duotone-kiteboarding.webp",
    "duotone wetsuits"                        => "/brand-logos/duotone.webp",
    "duotone windsurf boards"                 => "/brand-logos/duotone-windsurfing.webp",
    "duotone windsurf booms"                  => "/brand-logos/duotone-windsurfing.webp",
    "duotone windsurf harnesses"              => "/brand-logos/duotone-windsurfing.webp",
    "duotone windsurf masts"                  => "/brand-logos/duotone-windsurfing.webp",
    "duotone windsurf sails"                  => "/brand-logos/duotone-windsurfing.webp",
    "duotone windsurf wetsuits"               => "/brand-logos/duotone-windsurfing.webp",
    "duotone wing boards"                     => "/brand-logos/duotone-wing-foiling.webp",
    "duotone wing foil boards"                => "/brand-logos/duotone-wing-foiling.webp",
    "duotone wing foils"                      => "/brand-logos/duotone-wing-foiling.webp",
    "duotone wing harnesses"                  => "/brand-logos/duotone-wing-foiling.webp",
    "duotone wings 2026"                      => "/brand-logos/duotone-wing-foiling.webp",
    "duotone sup boards"                      => "/brand-logos/duotone.webp",
    "duotone sup paddles"                     => "/brand-logos/duotone.webp",
    "duotone sup boards & paddles 2026"       => "/brand-logos/duotone.webp",
    "vendor_duotone kiteboarding"             => "/brand-logos/duotone-kiteboarding.webp",
    # ION
    "ion water"                               => "/brand-logos/ion-water.png",
    "ion"                                     => "/brand-logos/ion-water.png",
    "ion water wetsuits & harnesses 2026"     => "/brand-logos/ion-water.png",
    "ion bike"                                => "/brand-logos/ion-water.png",
    "ion wetsuits 2026"                       => "/brand-logos/ion-water.png",
    "ion kite & windsurf harnesses"           => "/brand-logos/ion-water.png",
    # NeilPryde
    "neilpryde"                               => "/brand-logos/neilpryde.webp",
    "neil pryde"                              => "/brand-logos/neilpryde.webp",
    "neilpryde sails & wetsuits 2026"         => "/brand-logos/neilpryde.webp",
    "neilpryde windsurf sails 2026"           => "/brand-logos/neilpryde.webp",
    "neilpryde wetsuits"                      => "/brand-logos/neilpryde.webp",
    "neilpryde wings"                         => "/brand-logos/neilpryde.webp",
    "neilpryde windsurf masts"                => "/brand-logos/neilpryde.webp",
    # Cabrinha
    "cabrinha kites & kiteboards 2026"        => "/brand-logos/cabrinha-2 _1_.png.webp",
    "cabrinha kites 2026"                     => "/brand-logos/cabrinha-2 _1_.png.webp",
    "cabrinha kiteboards"                     => "/brand-logos/cabrinha-2 _1_.png.webp",
    "cabrinha kite bars"                      => "/brand-logos/cabrinha-2 _1_.png.webp",
    "cabrinha"                                => "/brand-logos/cabrinha-2 _1_.png.webp",
    # Gaastra
    "gaastra windsurf sails & kites 2026"     => "/brand-logos/gaastra.png",
    "gaastra windsurf sails"                  => "/brand-logos/gaastra.png",
    "gaastra"                                 => "/brand-logos/gaastra.png",
    # Tabou
    "tabou"                                   => "/brand-logos/tabou.png",
    "tabou windsurf boards"                   => "/brand-logos/tabou.png",
    "tabou wave boards"                       => "/brand-logos/tabou.png",
    "tabou foil boards"                       => "/brand-logos/tabou.png",
    "tabou accessories"                       => "/brand-logos/tabou.png",
    # JP Australia
    "jp australia sup & windsurf boards 2026" => "/brand-logos/jp-australia.png",
    "jp australia sup & windsurf boards"      => "/brand-logos/jp-australia.png",
    "jp australia"                            => "/brand-logos/jp-australia.png",
    # Nobile
    "nobile"                                  => "/brand-logos/nobile.webp",
    "nobile kiteboards & foils 2026"          => "/brand-logos/nobile.webp",
    "nobile kites"                            => "/brand-logos/nobile.webp",
    "nobile kite bars"                        => "/brand-logos/nobile.webp",
    "nobile harnesses"                        => "/brand-logos/nobile.webp",
    "nobile kiteboards"                       => "/brand-logos/nobile.webp",
    "nobile foils"                            => "/brand-logos/nobile.webp",
  }.freeze

  # Invisible unicode chars that sneak in from CSV/Shopify imports.
  # e.g. zero-width space U+200B, NBSP U+00A0, BOM U+FEFF, word-joiner U+2060
  INVISIBLE_UNICODE = /[\u200B-\u200D\uFEFF\u00A0\u2060\u180E]+/

  # Prefix fallback: catches any unmapped sub-taxon of a known brand
  BRAND_PREFIX_MAP = [
    ["duotone",    "/brand-logos/duotone.webp"],
    ["ion",        "/brand-logos/ion-water.png"],
    ["neilpryde",  "/brand-logos/neilpryde.webp"],
    ["cabrinha",   "/brand-logos/cabrinha-2 _1_.png.webp"],
    ["gaastra",    "/brand-logos/gaastra.png"],
    ["tabou",      "/brand-logos/tabou.png"],
    ["jp austral", "/brand-logos/jp-australia.png"],
    ["nobile",     "/brand-logos/nobile.webp"],
  ].freeze

  def brand_logo_path_for(brand_taxon)
    return nil unless brand_taxon

    # Strip invisible unicode (zero-width spaces etc. from CSV imports)
    clean_name = brand_taxon.name.downcase.gsub(INVISIBLE_UNICODE, '').strip

    # Exact map lookup first
    return BRAND_LOGO_MAP[clean_name] if BRAND_LOGO_MAP.key?(clean_name)

    # Prefix fallback for any unmapped sub-taxon
    BRAND_PREFIX_MAP.each do |prefix, logo|
      return logo if clean_name.start_with?(prefix)
    end

    nil
  end
end
