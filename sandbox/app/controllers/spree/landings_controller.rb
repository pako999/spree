# frozen_string_literal: true

# Marketing landing pages (e.g. /lp/e-foil-duotone) used for paid-traffic
# campaigns. Inherits Spree::StoreController so it renders inside the
# storefront layout (header/footer/theme) and gets Cloudflare edge caching
# on the #show action via Spree::CacheableStorefront.
module Spree
  class LandingsController < Spree::StoreController
    # Whitelist of public landing pages: url slug => view template basename.
    # Prevents rendering arbitrary templates from a user-supplied slug.
    PAGES = {
      'e-foil-duotone' => 'e_foil_duotone'
    }.freeze

    def show
      template = PAGES[params[:slug].to_s]
      raise ActiveRecord::RecordNotFound, "Unknown landing page: #{params[:slug]}" unless template

      load_landing_products
      render "spree/landings/#{template}"
    end

    private

    # Pull the Duotone E-Foil products straight from the live catalog so the
    # landing page stays in sync with stock/pricing. Falls back gracefully so
    # the page still renders (with a category CTA) if nothing matches.
    def load_landing_products
      @efoil_taxon = Spree::Taxon
                     .where('lower(name) LIKE ? OR lower(name) LIKE ? OR lower(name) LIKE ?',
                            '%e-foil%', '%efoil%', '%e foil%')
                     .first
      brand_taxon = Spree::Taxon.where('lower(name) LIKE ?', '%duotone%').first

      product_ids =
        if @efoil_taxon
          efoil_ids = @efoil_taxon.products.pluck(:id)
          if brand_taxon
            both = efoil_ids & brand_taxon.products.pluck(:id)
            both.presence || efoil_ids
          else
            efoil_ids
          end
        else
          Spree::Product
            .where('lower(name) LIKE ?', '%foil%')
            .where('lower(name) LIKE ?', '%duotone%')
            .pluck(:id)
        end

      @products = Spree::Product
                  .available
                  .distinct
                  .where(id: product_ids)
                  .includes(
                    master: %i[images prices],
                    variants: %i[images prices]
                  )
                  .limit(8)
                  .to_a

      @shop_url = if @efoil_taxon
                    spree.nested_taxons_path(@efoil_taxon)
                  else
                    spree.products_path(q: { name_cont: 'duotone foil' })
                  end
    end
  end
end
