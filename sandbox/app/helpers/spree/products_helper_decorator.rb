module Spree
  module ProductsHelperDecorator
    # Override to generate locale-free canonical URLs in BreadcrumbList JSON-LD.
    # The gem generates locale-prefixed URLs (e.g. /sl-SI/t/categories/...) which
    # mismatch the actual canonical URLs for the default locale.
    def product_json_ld_breadcrumbs(product)
      I18n.with_locale(I18n.default_locale) do
        super
      end
    end
  end
end

Spree::ProductsHelper.prepend(Spree::ProductsHelperDecorator)
