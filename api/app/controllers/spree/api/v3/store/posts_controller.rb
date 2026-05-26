# frozen_string_literal: true

module Spree
  module Api
    module V3
      module Store
        class PostsController < ResourceController
          # GET    /api/v3/store/posts         — publishable key OK
          # GET    /api/v3/store/posts/:id     — publishable key OK
          # POST   /api/v3/store/posts         — secret key required
          # PATCH  /api/v3/store/posts/:id     — secret key required
          # DELETE /api/v3/store/posts/:id     — secret key required

          # Require secret key for write operations — skip parent publishable-only check
          skip_before_action :authenticate_api_key!, only: [:create, :update, :destroy], raise: false
          before_action :authenticate_secret_key!, only: [:create, :update, :destroy]

          # Override write actions to skip CanCan — secret key is the only auth gate needed.

          def create
            @resource = build_resource
            if @resource.save
              render json: serialize_resource(@resource), status: :created
            else
              render_errors(@resource.errors)
            end
          end

          def update
            set_resource
            if @resource.update(permitted_params)
              render json: serialize_resource(@resource)
            else
              render_errors(@resource.errors)
            end
          end

          def destroy
            set_resource
            @resource.destroy
            head :no_content
          end

          protected

          def model_class
            Spree::Post
          end

          def serializer_class
            Spree::Api::V3::PostSerializer
          end

          # Scope to current store; show published posts to unauthenticated users,
          # all posts (including drafts) to authenticated API key holders.
          def scope
            base = Spree::Post.where(store: current_store)
            current_user.present? ? base : base.published
          end

          # Resolve by prefixed ID (post_xxx) or friendly slug
          def find_resource
            id = params[:id]
            if id.to_s.start_with?('post_')
              scope.find_by_prefix_id!(id)
            else
              scope.friendly.find(id)
            end
          end

          def build_resource
            scope.new(permitted_params).tap do |post|
              post.store = current_store
            end
          end

          def permitted_params
            p = params.require(:post).permit(
              :title,
              :slug,
              :content,
              :excerpt,
              :meta_title,
              :meta_description,
              :published_at,
              :post_category_id,
              :image          # ActiveStorage direct-upload signed_id or multipart file
            )

            # Allow passing image as a signed_id string (direct upload)
            if params.dig(:post, :image).is_a?(String)
              p[:image] = params[:post][:image]
            end

            p
          end

        end
      end
    end
  end
end
