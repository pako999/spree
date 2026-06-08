# frozen_string_literal: true

# Exports Spree::Post records to JSON for import into Shopify.
#
# Usage (run inside the surf-store container):
#   bundle exec rails runner script/export_posts_to_shopify.rb
#
# Output: /rails/tmp/spree_posts_export.json
#
# The JSON structure mirrors Shopify's Article object so the importer
# script can pass each entry to the Admin API with minimal transformation.

require 'json'
require 'uri'

OUTPUT_PATH = '/rails/tmp/spree_posts_export.json'
PUBLIC_HOST = 'https://www.surf-store.com'

# Map Spree post categories (slug) → Shopify blog handle.
# Add entries here as you create blogs in Shopify Admin → Online Store → Blogs.
# Posts whose category isn't mapped fall back to DEFAULT_BLOG.
DEFAULT_BLOG = 'news'
CATEGORY_TO_BLOG = {
  # 'kitesurfing-tips' => 'kitesurfing',
  # 'product-reviews'  => 'reviews',
  # 'travel'           => 'travel'
}.freeze

def absolute_url(rel_path)
  return rel_path if rel_path.blank?
  return rel_path if rel_path.start_with?('http://', 'https://')
  URI.join(PUBLIC_HOST, rel_path).to_s
end

# Convert <action_text-attachment> tags and rewrite relative image URLs to
# absolute URLs that Shopify can fetch from outside the Spree server.
def rewrite_content_html(html)
  return '' if html.blank?

  body = html.to_s

  # ActionText embeds blob images as <action-text-attachment sgid="..." url="/rails/active_storage/blobs/.../filename.jpg">
  # Shopify can't read /rails/active_storage; we need the public absolute URL.
  body = body.gsub(/(src|href)="(\/rails\/[^"]+)"/) do
    attr  = Regexp.last_match(1)
    path  = Regexp.last_match(2)
    %(#{attr}="#{PUBLIC_HOST}#{path}")
  end

  body
end

posts = Spree::Post.published.order(:published_at)

puts "Found #{posts.size} published posts"

exported = posts.map do |post|
  category_slug = post.post_category&.slug
  blog_handle   = CATEGORY_TO_BLOG[category_slug] || DEFAULT_BLOG

  image_url =
    if post.image.attached?
      begin
        Rails.application.routes.url_helpers.rails_blob_url(
          post.image,
          host: PUBLIC_HOST.sub('https://', '').sub('http://', ''),
          protocol: 'https'
        )
      rescue StandardError => e
        Rails.logger.warn "[export_posts] image url failed for #{post.slug}: #{e.message}"
        nil
      end
    end

  tags = post.tag_list.to_a rescue []

  {
    blog_handle:       blog_handle,
    handle:            post.slug,
    title:             post.title,
    author:            post.author_name.presence || 'Surf-Store Team',
    body_html:         rewrite_content_html(post.content.body&.to_html),
    summary_html:      rewrite_content_html(post.excerpt.body&.to_html),
    image_url:         image_url,
    tags:              tags,
    published_at:      post.published_at&.iso8601,
    seo_title:         post.meta_title.presence || post.title,
    seo_description:   post.meta_description.presence || post.description.to_s[0, 320],
    original_url:      "#{PUBLIC_HOST}/en/posts/#{post.slug}"
  }
end

File.write(OUTPUT_PATH, JSON.pretty_generate(exported))
puts "Wrote #{exported.size} posts to #{OUTPUT_PATH}"
puts "First 3 entries preview:"
puts JSON.pretty_generate(exported.first(3))
