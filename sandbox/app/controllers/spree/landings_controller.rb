# frozen_string_literal: true

module Spree
  class LandingsController < Spree::StoreController
    # Slug → template basename mapping.
    # Add new landing pages here; each gets its own view in app/views/spree/landings/.
    PAGES = {
      'e-foil-duotone' => 'e_foil_duotone'
    }.freeze

    def show
      @slug = params[:slug].to_s
      template = PAGES[@slug]
      return redirect_to '/', status: 302 unless template

      load_landing_products if @slug == 'e-foil-duotone'
      render template: "spree/landings/#{template}"
    end

    private

    # Load Duotone E-Foil products from the e-foil taxon.
    # @products — ActiveRecord relation of products to render in the grid.
    # @shop_url — URL to the full e-foil category page.
    def load_landing_products
      store = current_store

      efoil_taxon  = Spree::Taxon.find_by(permalink: 'categories/e-foil')
      brand_taxon  = Spree::Taxon.find_by(permalink: 'brands/duotone')

      @shop_url = efoil_taxon ? "/t/#{efoil_taxon.permalink}" : '/t/categories/e-foil'

      if efoil_taxon && brand_taxon
        @products = Spree::Product
          .active
          .where(deleted_at: nil)
          .joins(:stores).where(spree_stores: { id: store.id })
          .joins(:taxons)
          .where(spree_taxons: { id: [efoil_taxon.id] + efoil_taxon.descendants.ids })
          .merge(Spree::Product.joins(:taxons).where(spree_taxons: { id: brand_taxon.id }))
          .distinct
          .includes(
            master: [:images, :prices, { stock_items: :stock_location }],
            variants: [:images, :prices, { stock_items: :stock_location }, { option_values: :option_type }]
          )
          .order(:name)
      else
        @products = Spree::Product.none
      end
    end
  end
end
