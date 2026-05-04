module BrandLogoHelper
  # Maps downcased brand taxon names to real logo files in /public/brand-logos/.
  # Only entries with genuine image/vector logos — no fake text SVGs.
  # Add more entries here as real logo files are added to public/brand-logos/.
  BRAND_LOGO_MAP = {
    "duotone"              => "/brand-logos/duotone.webp",
    "duotone kiteboarding" => "/brand-logos/duotone.webp",
    "duotone windsurfing"  => "/brand-logos/duotone.webp",
    "duotone wing foiling" => "/brand-logos/duotone.webp",
    "duotone wing"         => "/brand-logos/duotone.webp",
    "duotone sup"          => "/brand-logos/duotone.webp",
    "duotone apparel"      => "/brand-logos/duotone.webp",
    "duotone foiling & electric" => "/brand-logos/duotone.webp",
    "duotone foilwing"     => "/brand-logos/duotone.webp",
    "duotone kite bars"    => "/brand-logos/duotone.webp",
    "duotone kiteboards"   => "/brand-logos/duotone.webp",
    "duotone kites"        => "/brand-logos/duotone.webp",
    "duotone sup boards & paddles 2026" => "/brand-logos/duotone.webp",
    "duotone windsurf booms" => "/brand-logos/duotone.webp",
    "duotone windsurf masts" => "/brand-logos/duotone.webp",
    "duotone windsurf sails" => "/brand-logos/duotone.webp",
    "duotone wings 2026"   => "/brand-logos/duotone.webp",
    "ion water"            => "/brand-logos/ion-water.png",
    "ion"                  => "/brand-logos/ion-water.png",
    "ion bike"             => "/brand-logos/ion-water.png",
    "neilpryde"            => "/brand-logos/neilpryde.webp",
    "neil pryde"           => "/brand-logos/neilpryde.webp",
    "neilpryde sails & wetsuits 2026" => "/brand-logos/neilpryde.webp",
    "neilpryde windsurf sails 2026"   => "/brand-logos/neilpryde.webp",
    "cabrinha"                        => "/brand-logos/cabrinha-2 _1_.png.webp",
    "cabrinha kites"                  => "/brand-logos/cabrinha-2 _1_.png.webp",
    "cabrinha kiteboards"             => "/brand-logos/cabrinha-2 _1_.png.webp",
    "cabrinha bars"                   => "/brand-logos/cabrinha-2 _1_.png.webp",
    "cabrinha foil"                   => "/brand-logos/cabrinha-2 _1_.png.webp",
    "gaastra"                         => "/brand-logos/gaastra.svg",
    "ga sails"                        => "/brand-logos/gaastra.svg",
    "gaastra kites"                   => "/brand-logos/gaastra.svg",
    "gaastra sails"                   => "/brand-logos/gaastra.svg",
    "tabou"                           => "/brand-logos/gaastra.svg",
    "jp australia"                    => "/brand-logos/jp-australia.png",
    "jp"                              => "/brand-logos/jp-australia.png",
    # Add more brands here when real logo files are added to public/brand-logos/
  }.freeze

  def brand_logo_path_for(brand_taxon)
    return nil unless brand_taxon
    BRAND_LOGO_MAP[brand_taxon.name.downcase.strip]
  end
end
