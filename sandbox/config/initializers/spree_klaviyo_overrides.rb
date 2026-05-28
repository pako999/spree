# frozen_string_literal: true

# Fix two bugs in SpreeKlaviyo::ProductPresenter (spree_klaviyo 1.1.2):
#
# Bug 1 — Wrong product URL in emails:
#   The presenter uses `store: @store` but the ivar is `@current_store`.
#   `@store` is nil, so `spree_storefront_resource_url` uses the wrong default
#   host — which was the old Shopify domain.
#
# Bug 2 — Missing product image in emails:
#   `spree_image_url` in a background job has no request context, so the
#   generated URL has no host (or a wrong host like localhost).
#   We build the image URL directly from the ActiveStorage blob + store host.

Rails.application.config.after_initialize do
  SpreeKlaviyo::ProductPresenter.class_eval do
    def call
      return {} if @product.nil?

      store_host = @current_store&.url.presence || 'www.surf-store.com'
      store_url  = "https://#{store_host}"

      product_url = "#{store_url}/products/#{@product.slug}"

      image     = @product.default_image
      image_url = build_image_url(image, store_url)

      {
        name:       @product.name,
        price:      @product.amount_in(current_currency)&.to_f,
        brand:      @product&.brand_name,
        category:   @product.main_taxon&.pretty_name,
        currency:   current_currency,
        url:        product_url,
        image_url:  image_url,
        sku:        @product.sku
      }
    end

    private

    def build_image_url(image, store_url)
      return '' unless image.present? && image.attachment.attached?

      # Generate a variant URL (resized) if possible, otherwise fall back to
      # the original blob URL. Both are absolute with the correct store host.
      blob_path = Rails.application.routes.url_helpers.rails_blob_path(
        image.attachment, only_path: true
      )
      "#{store_url}#{blob_path}"
    rescue StandardError => e
      Rails.logger.warn "[KlaviyoProductPresenter] image_url error: #{e.message}"
      ''
    end
  end
end
