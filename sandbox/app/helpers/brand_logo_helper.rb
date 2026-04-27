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
    "ion water"            => "/brand-logos/ion-water.png",
    "ion"                  => "/brand-logos/ion-water.png",
    "neilpryde"            => "/brand-logos/neilpryde.webp",
    "neil pryde"           => "/brand-logos/neilpryde.webp",
  }.freeze

  def brand_logo_path_for(brand_taxon)
    return nil unless brand_taxon
    BRAND_LOGO_MAP[brand_taxon.name.downcase.strip]
  end
end
