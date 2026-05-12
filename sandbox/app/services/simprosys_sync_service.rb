# frozen_string_literal: true

# Service to sync Spree products to Simprosys Google Feed API
# Usage:
#   SimprosysSyncService.new.sync_all          # full sync
#   SimprosysSyncService.new.sync_product(id)  # single product
class SimprosysSyncService
  BASE_URL = "https://api.simprosysapis.com"
  BATCH_SIZE = 100 # max 500 products per batch request

  def initialize
    @client_id = ENV.fetch("SIMPROSYS_CLIENT_ID")
    @client_secret = ENV.fetch("SIMPROSYS_CLIENT_SECRET")
    @shop_id = ENV.fetch("SIMPROSYS_SHOP_ID")
    @store = Spree::Store.default
    @currency = "EUR"
    @base_product_url = "https://www.surf-store.com/products"
  end

  # Full sync: push all active products with variants to Simprosys
  def sync_all
    authenticate!

    products = @store.products
                     .active(@currency)
                     .includes(
                       :taxons,
                       master: [:images, :prices, { stock_items: :stock_location }],
                       variants: [:images, :prices, { stock_items: :stock_location }, { option_values: :option_type }],
                       option_types: []
                     )

    total = products.count
    Rails.logger.info "[Simprosys] Starting sync of #{total} products"

    synced = 0
    skipped = 0
    errors = []

    products.find_in_batches(batch_size: BATCH_SIZE) do |batch|
      payload_products = batch.filter_map do |product|
        build_product_payload(product)
      rescue => e
        errors << { product_id: product.id, name: product.name, error: e.message }
        nil
      end

      next if payload_products.empty?

      response = bulk_upsert_products(payload_products)

      if response[:status]
        synced += payload_products.size
        Rails.logger.info "[Simprosys] Batch synced: #{payload_products.size} products"
      else
        errors << { batch_size: payload_products.size, error: response[:message] }
        Rails.logger.error "[Simprosys] Batch error: #{response[:message]}"
      end
    end

    summary = { total: total, synced: synced, skipped: total - synced - errors.size, errors: errors }
    Rails.logger.info "[Simprosys] Sync complete: #{summary.except(:errors).inspect}"
    Rails.logger.info "[Simprosys] Errors: #{errors.size}" if errors.any?
    summary
  end

  # Sync a single product by Spree product ID
  def sync_product(product_id)
    authenticate!
    product = @store.products.find(product_id)
    payload = build_product_payload(product)
    upsert_product(payload)
  end

  private

  def authenticate!
    response = post("/api/v1/token/", {
      client_id: @client_id,
      client_secret: @client_secret
    }, authenticated: false)

    if response[:status]
      @access_token = response.dig(:data, "access_token") || response.dig(:data, :access_token)
      @refresh_token = response.dig(:data, "refresh_token") || response.dig(:data, :refresh_token)
      Rails.logger.info "[Simprosys] Authenticated successfully"
    else
      raise "Simprosys auth failed: #{response[:message]}"
    end
  end

  def build_product_payload(product)
    sellable_variants = product.variants.select { |v| v.price.present? && v.price > 0 }

    # If no sellable variants, use master
    if sellable_variants.empty?
      master = product.master
      return nil unless master.price.present? && master.price > 0

      sellable_variants = [master]
    end

    # Build options map from option types
    options = {}
    product.option_types.each_with_index do |ot, idx|
      options[(idx + 1).to_s] = ot.presentation
    end

    brand = product.brand_taxon&.name || ""
    product_type = product.taxons.reject { |t| t.taxonomy&.name == "Brands" }.first&.pretty_name || ""

    # Google product category for sporting goods
    google_category = {
      category_id: 1011,
      category_name: "Sporting Goods"
    }

    {
      product_id: product.id.to_s[0..23], # max 24 chars
      title: product.name.truncate(200),
      description: (product.description || "").truncate(10000),
      brand: brand.truncate(70),
      product_type: product_type.truncate(750),
      canonical_link: "#{@base_product_url}/#{product.slug}",
      options: options,
      google_product_category: google_category,
      variants: sellable_variants.map { |v| build_variant_payload(product, v) }
    }
  end

  def build_variant_payload(product, variant)
    in_stock = variant.stock_items.any? { |si| si.count_on_hand > 0 || si.backorderable }
    availability = in_stock ? "in_stock" : "out_of_stock"

    # Build image URLs
    images = variant.images.presence || product.master.images
    image_link = images.first ? image_url(images.first) : ""
    additional_images = images.drop(1).first(10).map { |img| image_url(img) }

    # Build option values map
    values = {}
    variant.option_values.each do |ov|
      values[ov.option_type.presentation] = ov.presentation
    end

    # Variant-specific link with options
    variant_link = "#{@base_product_url}/#{product.slug}"

    # SKU / EAN
    sku = variant.sku.presence || ""
    # Check if product or variant has a barcode/EAN in properties
    gtin = ""
    if variant.respond_to?(:barcode) && variant.barcode.present?
      gtin = variant.barcode
    end

    sale_price = nil
    sale_effective = nil
    if variant.respond_to?(:compare_at_price) && variant.compare_at_price.present? && variant.compare_at_price > variant.price
      sale_price = variant.price.to_f
    end

    payload = {
      variant_id: variant.id.to_s[0..23],
      offer_id: (sku.presence || variant.id.to_s).gsub(/[^A-Za-z0-9_\-]/, "_")[0..49],
      price: (sale_price ? variant.compare_at_price.to_f : variant.price.to_f),
      link: variant_link,
      image_link: image_link,
      sku: sku.truncate(70),
      availability: availability,
      condition: "new",
      values: values
    }

    payload[:additional_image_links] = additional_images if additional_images.any?
    payload[:gtin] = gtin if gtin.present?
    payload[:sale_price] = sale_price if sale_price
    payload[:sale_price_effective_date] = sale_effective if sale_effective
    payload[:inventory_qty] = variant.stock_items.sum(&:count_on_hand).clamp(0, 999999)

    # Weight
    if variant.weight.present? && variant.weight > 0
      payload[:shipping_weight] = { value: variant.weight.to_f, unit: "kg" }
      payload[:weight] = { value: variant.weight.to_f, unit: "kg" }
    end

    payload
  end

  def image_url(image)
    if image.attachment.blob.present?
      "https://www.surf-store.com/rails/active_storage/blobs/redirect/#{image.attachment.blob.signed_id}/#{image.attachment.blob.filename}"
    else
      ""
    end
  end

  def upsert_product(product_payload)
    post("/api/v1/products/", {
      shop_id: @shop_id,
      product: product_payload,
      upsert: true
    })
  end

  def bulk_upsert_products(products_payload)
    post("/api/v1/bulk-products/", {
      shop_id: @shop_id,
      products: products_payload,
      upsert: true
    })
  end

  # HTTP helpers
  def post(path, body, authenticated: true)
    uri = URI("#{BASE_URL}#{path}")
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.open_timeout = 10
    http.read_timeout = 60

    request = Net::HTTP::Post.new(uri)
    request["Content-Type"] = "application/json"
    request["Authorization"] = "Bearer #{@access_token}" if authenticated
    request.body = body.to_json

    response = http.request(request)
    parsed = JSON.parse(response.body, symbolize_names: false)

    {
      status: parsed["status"],
      code: parsed["code"],
      message: parsed["message"],
      data: parsed["data"]
    }
  rescue => e
    { status: false, code: 0, message: e.message, data: nil }
  end
end
