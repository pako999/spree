module Spree
  module PageSections
    class SportCategoryGrid < Spree::PageSection
      preference :panel_height, :integer, default: 480

      def icon_name
        'layout-grid'
      end

      def links_available?
        true
      end

      def allowed_linkable_types
        [
          [Spree.t(:taxon), 'Spree::Taxon']
        ]
      end

      def default_linkable_type
        'Spree::Taxon'
      end
    end
  end
end
