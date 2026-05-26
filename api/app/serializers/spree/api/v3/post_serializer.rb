# frozen_string_literal: true

module Spree
  module Api
    module V3
      class PostSerializer < BaseSerializer
        typelize title: :string,
                 slug: 'string | null',
                 excerpt: 'string | null',
                 content: 'string | null',
                 meta_title: 'string | null',
                 meta_description: 'string | null',
                 published_at: 'string | null',
                 image_url: 'string | null',
                 category_id: 'string | null',
                 category_title: 'string | null'

        attributes :title, :slug, :meta_title, :meta_description

        attribute :published_at do |post|
          post.published_at&.iso8601
        end

        attribute :created_at do |post|
          post.created_at&.iso8601
        end

        attribute :updated_at do |post|
          post.updated_at&.iso8601
        end

        # Body content — Spree::Post uses ActionText (has_rich_text :content)
        attribute :content do |post|
          post.content.to_s
        end

        attribute :excerpt do |post|
          post.excerpt.to_s
        end

        # Hero image URL (full size via ActiveStorage)
        attribute :image_url do |post|
          next nil unless post.image.attached?

          Rails.application.routes.url_helpers.rails_blob_url(
            post.image,
            host: Spree::Store.current&.url || 'www.surf-store.com'
          )
        rescue StandardError
          nil
        end

        # Category
        attribute :category_id do |post|
          post.post_category_id&.to_s
        end

        attribute :category_title do |post|
          post.post_category&.title
        end
      end
    end
  end
end
