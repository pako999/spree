module BrandLogoHelper
  # Maps downcased brand taxon names to real logo files in /public/brand-logos/.
  # Keys must match taxon.name.downcase.strip exactly as stored in the DB.
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
    "duotone kiteboards"                      => "/brand-logos/duotone-kiteboarding.webp",
    "duotone kites"                           => "/brand-logos/duotone-kiteboarding.webp",
    "duotone kite harnesses"                  => "/brand-logos/duotone-kiteboarding.webp",
    "duotone wing foils"                      => "/brand-logos/duotone-wing-foiling.webp",
    "duotone sup boards & paddles 2026"       => "/brand-logos/duotone.webp",
    "duotone windsurf booms"                  => "/brand-logos/duotone-windsurfing.webp",
    "duotone windsurf masts"                  => "/brand-logos/duotone-windsurfing.webp",
    "duotone windsurf sails"                  => "/brand-logos/duotone-windsurfing.webp",
    "duotone wings 2026"                      => "/brand-logos/duotone-wing-foiling.webp",
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
    # Tabou (correct logo - separate brand from Gaastra)
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
    "nobile"                                  => "/brand-logos/nobile.png",
    "nobile kiteboards & foils 2026"          => "/brand-logos/nobile.png",
    "nobile kites"                            => "/brand-logos/nobile.png",
    "nobile kite bars"                        => "/brand-logos/nobile.png",
    "nobile harnesses"                        => "/brand-logos/nobile.png",
    "nobile kiteboards"                       => "/brand-logos/nobile.png",
    "nobile foils"                            => "/brand-logos/nobile.png",
  }.freeze

  def brand_logo_path_for(brand_taxon)
    return nil unless brand_taxon
    BRAND_LOGO_MAP[brand_taxon.name.downcase.strip]
  end
end
