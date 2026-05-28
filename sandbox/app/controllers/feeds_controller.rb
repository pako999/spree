# frozen_string_literal: true

require 'cgi'

# Generates a Google Merchant Center product feed (RSS 2.0 with g: namespace).
# Served at GET /feeds/google-shopping.xml — submit this URL to Google Merchant Center.
#
# Cached for 4 hours. To force refresh:
#   Rails.cache.delete('feeds/google_shopping_v1')
class FeedsController < ApplicationController
  CACHE_TTL  = 30.minutes
  STORE_URL  = 'https://www.surf-store.com'
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
    @items      = Rails.cache.fetch('feeds/google_shopping_v8', expires_in: CACHE_TTL) do
      build_items
    end
    render layout: false, content_type: 'application/xml'
  end

  private

  def build_items
    items   = []
    skipped = Hash.new(0)

    products = Spree::Product
      .active
      .where(deleted_at: nil)
      .where('discontinue_on IS NULL OR discontinue_on > ?', Time.current)
      .joins(:stores).where(spree_stores: { id: STORE_ID })
      .includes(
        :taxons,
        :tags,
        master: [:images, :prices, { stock_items: :stock_location },
                 { option_values: :option_type }],
        variants: [:images, :prices, { stock_items: :stock_location },
                   { option_values: :option_type }]
      )

    products.find_each do |product|
      taxon_perms = product.taxons.map(&:permalink)
      brand_taxon = product.taxons.find { |t| t.permalink.start_with?('brands/') }
      raw_brand = if brand_taxon
        slug = brand_taxon.permalink.delete_prefix('brands/').split('/').first
        # Never fall back to literal 'Unknown' — use the taxon name directly when
        # the slug isn't in BRAND_SLUG_TO_RAW (covers any brand added to the store
        # after this map was last updated).
        BRAND_SLUG_TO_RAW[slug] ||
          extract_brand_from_name(brand_taxon.name.gsub(/[^\x20-\x7E]/, '').strip) ||
          brand_taxon.name.gsub(/[^\x20-\x7E]/, '').strip.presence ||
          ''
      else
        extract_brand_from_name(product.name) || ''
      end
      brand = GoogleShoppingOptimizer.normalize_brand(raw_brand)

      google_cat   = google_category_for(taxon_perms)
      opt_type     = GoogleShoppingOptimizer.detect_product_type(product.name, raw_brand, taxon_perms)
      is_apparel   = taxon_perms.any? { |p| APPAREL_TAXON_PREFIXES.any? { |pf| p.start_with?(pf) } }
      is_ss26      = product.tags.any? { |t| t.name.casecmp?('ss26') } || product.name.include?('2026')

      real_variants   = product.variants.reject { |v| v.deleted_at.present? }
      has_variants    = real_variants.any?
      variants_to_use = has_variants ? real_variants : [product.master]
      fallback_image  = product.master.images.first

      product_url = "#{STORE_URL}/products/#{product.slug}"

      variants_to_use.each do |variant|
        image = variant.images.first || fallback_image
        unless image
          skipped[:no_image] += 1
          next
        end

        price_obj = variant.prices.find { |p| p.currency == 'EUR' } || variant.prices.first
        unless price_obj&.amount.to_f > 0
          skipped[:no_price] += 1
          next
        end

        total_stock      = variant.stock_items.sum(&:count_on_hand)
        is_backorderable = variant.stock_items.any?(&:backorderable?)

        # Exclusion: gift cards, shipping insurance, dead old-season stock (2023/2024/2025 zero-stock)
        if GoogleShoppingOptimizer.exclude?(product.name, total_stock, is_backorderable)
          skipped[:old_season_zero_stock] += 1
          next
        end

        color = variant.option_values.find { |ov| ov.option_type&.name == 'color' }&.presentation
        size  = variant.option_values.find { |ov| ov.option_type&.name == 'size'  }&.presentation

        all_images = (variant.images + product.master.images).uniq(&:id)
        additional_images = all_images.drop(1).first(10).filter_map { |img| blob_full_url(img.attachment) }

        compare_price = price_obj.respond_to?(:compare_at_amount) ? price_obj.compare_at_amount : nil
        on_sale       = compare_price.present? && compare_price > price_obj.amount
        display_price = on_sale ? format('%.2f %s', compare_price.to_f, price_obj.currency)
                                : format('%.2f %s', price_obj.amount.to_f, price_obj.currency)
        sale_price    = on_sale ? format('%.2f %s', price_obj.amount.to_f, price_obj.currency) : nil
        numeric_price = price_obj.amount.to_f

        raw_id = variant.sku.presence || "spree-#{variant.id}"

        items << {
          id:                      raw_id.length > 50 ? "var-#{variant.id}" : raw_id,
          item_group_id:           has_variants ? "spree-#{product.id}" : nil,
          title:                   GoogleShoppingOptimizer.build_title(product.name, raw_brand, opt_type, color, size),
          description:             strip_html(product.description),
          link:                    product_url,
          image_link:              blob_full_url(image.attachment),
          additional_image_links:  additional_images,
          price:                   display_price,
          sale_price:              sale_price,
          availability:            GoogleShoppingOptimizer.availability(total_stock, is_backorderable),
          condition:               'new',
          brand:                   brand,
          gtin:                    variant.barcode.presence,
          mpn:                     variant.sku.presence&.slice(0, 70),
          google_product_category: google_cat,
          product_type:            opt_type,
          color:                   color,
          size:                    size,
          gender:                  is_apparel ? 'unisex' : nil,
          custom_label_0:          GoogleShoppingOptimizer.custom_label_0_margin(opt_type),
          custom_label_2:          GoogleShoppingOptimizer.custom_label_2_season(product.name),
          custom_label_3:          GoogleShoppingOptimizer.custom_label_3_price_bucket(numeric_price),
          custom_label_4:          is_ss26 ? 'bestseller' : nil,
          shipping_weight:         variant.weight.present? && variant.weight > 0 ? format('%.2f kg', variant.weight.to_f) : nil,
        }
      end
    end

    Rails.logger.info "[GoogleFeed] Built #{items.size} feed items from #{products.size} products. " \
                      "Skipped variants: #{skipped.map { |k, v| "#{k}=#{v}" }.join(', ')}"
    items
  end

  def google_category_for(taxon_permalinks)
    GOOGLE_CATEGORY_MAP.each do |prefix, category|
      return category if taxon_permalinks.any? { |p| p.start_with?(prefix) }
    end
    'Sporting Goods > Water Sports'
  end

  # Kept for reference — title building now delegated to GoogleShoppingOptimizer.build_title

  def strip_html(text)
    # Strip tags first, then decode HTML entities (&amp;mdash; → —), then clean whitespace
    CGI.unescapeHTML(text.to_s.gsub(/<[^>]+>/, ' ')).squish.truncate(5000)
  end

  # Maps brands/ permalink slug → canonical raw brand name (used for type detection + normalisation)
  BRAND_SLUG_TO_RAW = {
    'cabrinha'                  => 'Cabrinha',
    'duotone-kiteboarding'      => 'Duotone Kiteboarding',
    'duotone-windsurfing'       => 'Duotone Windsurfing',
    'duotone-foilwing'          => 'Duotone Foilwing',
    'duotone-wing-foiling'      => 'Duotone Wing Foiling',
    'duotone-foiling-and-electric' => 'Duotone Foiling & Electric',
    'duotone-apparel'           => 'Duotone Apparel',
    'duotone-sup'               => 'Duotone SUP',
    'fanatic-sup'               => 'Fanatic SUP',
    'fanatic-windsurfing'       => 'Fanatic Windsurfing',
    'fanatic-x'                 => 'Fanatic X',
    'ion'                       => 'ION',
    'ion-water'                 => 'ION Water',
    'ion-bike'                  => 'ION Bike',
    'neilpryde'                 => 'NeilPryde',
    'nobile'                    => 'Nobile',
    'gaastra'                   => 'Gaastra',
    'tabou'                     => 'Tabou',
    'jp-australia'              => 'JP Australia',
    'point-7'                   => 'Point-7',
    'mystic'                    => 'Mystic',
    'prolimit'                  => 'Prolimit',
    'manera'                    => 'Manera',
    'dakine'                    => 'Dakine',
    'north'                     => 'North',
    'core'                      => 'CORE',
    'f-one'                     => 'F-One',
    'slingshot'                 => 'Slingshot',
    'eleveight'                 => 'Eleveight',
    'airush'                    => 'Airush',
    'ozone'                     => 'Ozone',
    'flysurfer'                 => 'Flysurfer',
    'rrd'                       => 'RRD',
    'severne'                   => 'Severne',
    'naish'                     => 'Naish',
    'starboard'                 => 'Starboard',
    'simmer'                    => 'Simmer',
  }.freeze

  # Known brands for fallback name extraction from product title
  KNOWN_BRANDS = %w[
    NeilPryde Duotone Cabrinha Fanatic JP-Australia RRD
    Nobile North Core F-One Slingshot Eleveight Gaastra
    Point-7 Simmer ION Mystic Tabou Severne Naish Starboard
    Prolimit Manera Dakine Airush Ozone Flysurfer HQ4
  ].freeze

  def extract_brand_from_name(name)
    return nil if name.blank?
    KNOWN_BRANDS.find { |b| name.match?(/\A#{Regexp.escape(b)}\b/i) }
  end

  # Build a human-readable product type breadcrumb from the deepest categories/ taxon.
  # e.g. "categories/kitesurfing/kiteboards/twin-tip" → "Kitesurfing > Kiteboards > Twin Tip"
  def product_type_for(taxon_permalinks)
    cat = taxon_permalinks
      .select { |p| p.start_with?('categories/') }
      .max_by(&:length)  # deepest path
    return nil unless cat

    cat.sub('categories/', '').split('/').map { |s| s.gsub('-', ' ').split.map(&:capitalize).join(' ') }.join(' > ')
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
