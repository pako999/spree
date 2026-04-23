# Handles old Shopify product URLs: /products/:slug
# Attempts to find a matching Spree product, falls back to category, then homepage.
class ShopifyRedirectsController < ApplicationController
  def product
    slug = params[:slug].to_s.downcase

    # Try exact slug match
    product = Spree::Product.find_by(slug: slug)
    if product
      redirect_to "/en/products/#{product.slug}", status: 301 and return
    end

    # Try partial match (Shopify slugs often differ slightly)
    product = Spree::Product.where("slug LIKE ?", "%#{slug.split('-').first(3).join('-')}%").first
    if product
      redirect_to "/en/products/#{product.slug}", status: 301 and return
    end

    # Try to match to a category based on slug keywords
    category_map = {
      'kite'      => '/t/categories/kitesurfing',
      'windsurf'  => '/t/categories/windsurf',
      'wing'      => '/t/categories/wingfoil',
      'wetsuit'   => '/t/categories/wetsuits',
      'neoprene'  => '/t/categories/wetsuits',
      'harness'   => '/t/categories/kitesurfing/kite-harnesses',
      'sup'       => '/t/categories/sup-board',
      'paddle'    => '/t/categories/sup-board',
      'foil'      => '/t/categories/wingfoil/wing-foils',
      'board'     => '/t/categories/kitesurfing/kiteboards',
      'sail'      => '/t/categories/windsurf/windsurf-sails',
      'mast'      => '/t/categories/windsurf/windsurf-gear',
      'boom'      => '/t/categories/windsurf/windsurf-gear',
      'helmet'    => '/t/categories/kitesurfing/protection-and-safety',
      'boot'      => '/t/categories/wetsuits/neoprene-accessories',
      'glove'     => '/t/categories/wetsuits/neoprene-accessories',
      'hood'      => '/t/categories/wetsuits/neoprene-accessories',
      'poncho'    => '/t/categories/apparel/ponchos',
      'boardshort' => '/t/categories/apparel/boardshorts',
      'lycra'     => '/t/categories/apparel/lycra',
      'efoil'     => '/t/categories/e-foil',
      'bike'      => '/t/brands/ion-bike'
    }

    category_map.each do |keyword, path|
      if slug.include?(keyword)
        redirect_to path, status: 301 and return
      end
    end

    # Final fallback: homepage
    redirect_to '/', status: 301
  end
end
