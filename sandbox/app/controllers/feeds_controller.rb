# frozen_string_literal: true

require 'cgi'

# Generates a Google Merchant Center product feed (RSS 2.0 with g: namespace).
# Served at GET /feeds/google-shopping.xml — submit this URL to Google Merchant Center.
#
# Cached for 4 hours. To force refresh:
#   Rails.cache.delete('feeds/google_shopping_v1')
class FeedsController < ApplicationController
  CACHE_TTL  = 4.hours
  STORE_URL  = 'https://surf-store.com'
  STORE_ID   = 2  # the main surf-store (matches store used during imports)

  # More specific prefixes must come before their parent prefixes
  GOOGLE_CATEGORY_MAP = {
    # Apparel sub-categories
    'categories/apparel/boardshorts'                         => 'Apparel & Accessories > Clothing > Shorts',
    'categories/apparel/tops'                                => 'Apparel & Accessories > Clothing > Shirts & Tops',
    'categories/apparel/lycra'                               => 'Apparel & Accessories > Clothing > Shirts & Tops',
    'categories/apparel/nylon-surf-shirt'                    => 'Apparel & Accessories > Clothing > Shirts & Tops',
    'categories/apparel/sun-protection'                      => 'Apparel & Accessories > Clothing > Shirts & Tops',
    'categories/apparel/coats'                               => 'Apparel & Accessories > Clothing > Outerwear',
    'categories/apparel/ponchos'                             => 'Apparel & Accessories > Clothing > Outerwear',
    'categories/apparel/cap'                                 => 'Apparel & Accessories > Clothing Accessories > Hats',
    'categories/apparel'                                     => 'Apparel & Accessories > Clothing',
    # Wetsuits & neoprene
    'categories/wetsuits/neoprene-accessories/gloves'        => 'Apparel & Accessories > Clothing Accessories > Gloves',
    'categories/wetsuits/neoprene-accessories/surf-shoes'    => 'Apparel & Accessories > Shoes > Water Shoes',
    'categories/wetsuits/neoprene-accessories'               => 'Apparel & Accessories > Clothing',
    'categories/wetsuits'                                    => 'Apparel & Accessories > Clothing > Swimwear',
    # Kite & wing
    'categories/kitesurfing/kites'                           => 'Sporting Goods > Water Sports > Kite Sports > Kites',
    'categories/kitesurfing/kiteboards'                      => 'Sporting Goods > Water Sports > Kite Sports > Kiteboards',
    'categories/kitesurfing/kite-harnesses'                  => 'Sporting Goods > Water Sports > Kite Sports > Harnesses',
    'categories/kitesurfing/kite-foil'                       => 'Sporting Goods > Water Sports',
    'categories/kitesurfing/protection-and-safety'           => 'Sporting Goods > Outdoor Recreation > Water Sports Safety > Buoyancy Aids & Life Jackets',
    'categories/kitesurfing'                                 => 'Sporting Goods > Water Sports > Kite Sports',
    'categories/wingfoil'                                    => 'Sporting Goods > Water Sports',
    # Windsurf
    'categories/windsurf/windsurf-sails'                     => 'Sporting Goods > Water Sports > Windsurfing > Sails',
    'categories/windsurf/windsurf-boards'                    => 'Sporting Goods > Water Sports > Windsurfing > Boards',
    'categories/windsurf/windsurf-foils'                     => 'Sporting Goods > Water Sports > Windsurfing',
    'categories/windsurf/windsurf-harnesses'                 => 'Sporting Goods > Water Sports > Windsurfing > Harnesses',
    'categories/windsurf/windsurf-gear'                      => 'Sporting Goods > Water Sports > Windsurfing',
    'categories/windsurf/windsurf-accessories'               => 'Sporting Goods > Water Sports > Windsurfing',
    'categories/windsurf'                                    => 'Sporting Goods > Water Sports > Windsurfing',
    # SUP
    'categories/sup-board/sup-paddles'                       => 'Sporting Goods > Water Sports > Surfing',
    'categories/sup-board'                                   => 'Sporting Goods > Water Sports > Surfing',
    # E-foil
    'categories/e-foil'                                      => 'Sporting Goods > Water Sports',
  }.freeze

  APPAREL_TAXON_PREFIXES = %w[
    categories/apparel
    categories/wetsuits
  ].freeze

  # GET /feeds/google-shopping.xml
  def google_shopping
    @store_name = 'Surf Store'
    @items      = Rails.cache.fetch('feeds/google_shopping_v2', expires_in: CACHE_TTL) do
      build_items
    end
    render layout: false, content_type: 'application/xml'
  end

  private

  def build_items
    items = []

    products = Spree::Product
      .active
      .where(deleted_at: nil)
      .joins(:stores).where(spree_stores: { id: STORE_ID })
      .includes(
        :taxons,
        master: [:images, :prices, { stock_items: :stock_location },
                 { option_values: :option_type }],
        variants: [:images, :prices, { stock_items: :stock_location },
                   { option_values: :option_type }]
      )

    products.find_each do |product|
      taxon_perms = product.taxons.map(&:permalink)
      brand       = product.taxons.find { |t| t.permalink.start_with?('brands/') }&.name
      google_cat  = google_category_for(taxon_perms)
      is_apparel  = taxon_perms.any? { |p| APPAREL_TAXON_PREFIXES.any? { |pf| p.start_with?(pf) } }

      real_variants   = product.variants.reject { |v| v.deleted_at.present? }
      has_variants    = real_variants.any?
      variants_to_use = has_variants ? real_variants : [product.master]
      fallback_image  = product.master.images.first

      product_url = "#{STORE_URL}/products/#{product.slug}"

      variants_to_use.each do |variant|
        image = variant.images.first || fallback_image
        next unless image  # Google requires at least one image

        price_obj = variant.prices.find { |p| p.currency == 'EUR' } || variant.prices.first
        next unless price_obj&.amount.to_f > 0

        total_stock = variant.stock_items.sum(&:count_on_hand)
        color = variant.option_values.find { |ov| ov.option_type&.name == 'color' }&.presentation
        size  = variant.option_values.find { |ov| ov.option_type&.name == 'size'  }&.presentation

        raw_id = variant.sku.presence || "spree-#{variant.id}"
        items << {
          id:                      raw_id.length > 50 ? "var-#{variant.id}" : raw_id,
          item_group_id:           has_variants ? "spree-#{product.id}" : nil,
          title:                   build_title(product.name, color, size),
          description:             strip_html(product.description),
          link:                    product_url,
          image_link:              blob_full_url(image.attachment),
          price:                   format('%.2f %s', price_obj.amount.to_f, price_obj.currency),
          availability:            total_stock > 0 ? 'in_stock' : 'out_of_stock',
          condition:               'new',
          brand:                   brand,
          gtin:                    variant.barcode.presence,
          mpn:                     variant.sku.presence&.slice(0, 70),
          google_product_category: google_cat,
          color:                   color,
          size:                    size,
          gender:                  is_apparel ? 'unisex' : nil,
        }
      end
    end

    items
  end

  def google_category_for(taxon_permalinks)
    GOOGLE_CATEGORY_MAP.each do |prefix, category|
      return category if taxon_permalinks.any? { |p| p.start_with?(prefix) }
    end
    'Sporting Goods > Water Sports'
  end

  def build_title(name, color, size)
    parts = [name]
    parts << color if color.present?
    parts << size  if size.present?
    parts.join(' - ').truncate(150)
  end

  def strip_html(text)
    # Strip tags first, then decode HTML entities (&amp;mdash; → —), then clean whitespace
    CGI.unescapeHTML(text.to_s.gsub(/<[^>]+>/, ' ')).squish.truncate(5000)
  end

  def blob_full_url(attachment)
    "#{STORE_URL}#{main_app.rails_blob_path(attachment, only_path: true)}"
  rescue StandardError
    nil
  end

  # GET /feeds/sitemap-seo.xml
  # SEO sitemap for taxon descriptions and blog posts
  public

  def sitemap_seo
    store    = Spree::Store.find(STORE_ID)
    base_url = "https://#{store.url}"

    urls = []

    # Taxons with SEO descriptions
    Spree::Taxon.where.not(description: [nil, '']).where('public_metadata IS NOT NULL').find_each do |t|
      urls << { loc: "#{base_url}/t/#{t.permalink}", lastmod: t.updated_at.iso8601, priority: '0.7' }
    end

    # Published posts
    Spree::Post.where.not(published_at: nil).find_each do |p|
      urls << { loc: "#{base_url}/en/posts/#{p.slug}", lastmod: p.updated_at.iso8601, priority: '0.6' }
    end

    xml = <<~XML
      <?xml version="1.0" encoding="UTF-8"?>
      <urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
      #{urls.map { |u| "  <url>\n    <loc>#{u[:loc]}</loc>\n    <lastmod>#{u[:lastmod]}</lastmod>\n    <priority>#{u[:priority]}</priority>\n  </url>" }.join("\n")}
      </urlset>
    XML

    render xml: xml
  end
end
