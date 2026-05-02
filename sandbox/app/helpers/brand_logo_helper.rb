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
    "cabrinha"             => "/brand-logos/cabrinha.png",
    "cabrinha kites & kiteboards 2026" => "/brand-logos/cabrinha.png",
    "cabrinha kites 2026"  => "/brand-logos/cabrinha.png",
    "fanatic"              => "/brand-logos/fanatic.png",
    "fanatic sup"          => "/brand-logos/fanatic.png",
    "fanatic windsurfing"  => "/brand-logos/fanatic.png",
    "fanatic x"            => "/brand-logos/fanatic.png",
    "gaastra"              => "/brand-logos/gaastra.png",
    "gaastra windsurf sails & kites 2026" => "/brand-logos/gaastra.png",
    "jp australia"         => "/brand-logos/jp-australia.png",
    "jp australia sup & windsurf boards" => "/brand-logos/jp-australia.png",
    "nobile"               => "/brand-logos/nobile.png",
    "nobile kiteboards & foils 2026" => "/brand-logos/nobile.png",
    "point7"               => "/brand-logos/point7.png",
    "point-7"              => "/brand-logos/point7.png",
    "tabou"                => "/brand-logos/tabou.png",
  }.freeze

  def brand_logo_path_for(brand_taxon)
    return nil unless brand_taxon
    BRAND_LOGO_MAP[brand_taxon.name.downcase.strip]
  end
end
