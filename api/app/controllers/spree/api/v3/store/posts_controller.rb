# frozen_string_literal: true

module Spree
  module Api
    module V3
      module Store
        class PostsController < ResourceController
          # GET    /api/v3/store/posts         — publishable OR secret key
          # GET    /api/v3/store/posts/:id     — publishable OR secret key
          # POST   /api/v3/store/posts         — secret key required
          # PATCH  /api/v3/store/posts/:id     — secret key required
          # DELETE /api/v3/store/posts/:id     — secret key required

          # Replace the parent publishable-only gate with one that accepts either
          # key type. Write actions additionally require the secret key.
          skip_before_action :authenticate_api_key!, raise: false
          before_action :authenticate_any_key!
          before_action :require_secret_key!, only: [:create, :update, :destroy]

          # ------------------------------------------------------------------ #
          # Write actions — CanCan is bypassed; secret key is the auth gate.   #
          # ------------------------------------------------------------------ #

          def create
            @resource = build_resource
            if @resource.save
              render json: serialize_resource(@resource), status: :created
            else
              render_errors(@resource.errors)
            end
          end

          def update
            # @resource already set by before_action :set_resource
            if @resource.update(permitted_params)
              render json: serialize_resource(@resource)
            else
              render_errors(@resource.errors)
            end
          end

          def destroy
            # @resource already set by before_action :set_resource
            @resource.destroy
            head :no_content
          end

          protected

          # ------------------------------------------------------------------ #
          # Authentication                                                       #
          # ------------------------------------------------------------------ #

          # Accept secret key OR publishable key. Sets @secret_key_authenticated
          # so downstream methods can gate draft visibility and CanCan.
          def authenticate_any_key!
            if (@current_api_key = current_store.api_keys.active.secret.find_by(token: extract_api_key))
              @secret_key_authenticated = true
              Spree::ApiKeyTouchJob.perform_later(@current_api_key.id)
            else
              # Fall back to publishable key (read-only)
              authenticate_api_key!
            end
          end

          # Gate write actions to secret key holders only.
          def require_secret_key!
            return if @secret_key_authenticated

            render_error(
              code: ErrorHandler::ERROR_CODES[:access_denied],
              message: 'Secret API key required for write operations.',
              status: :forbidden
            )
          end

          # ------------------------------------------------------------------ #
          # Authorization — skip CanCan for writes, secret key is the gate     #
          # ------------------------------------------------------------------ #

          # Override to skip CanCan for write actions — the secret key already
          # proved identity. CanCan still guards read actions (show/index).
          def set_resource
            @resource = find_resource
            authorize_resource!(@resource) unless write_action?
          end

          # ------------------------------------------------------------------ #
          # Scope                                                                #
          # ------------------------------------------------------------------ #

          # Secret-key holders can see ALL posts (drafts + published).
          # Publishable-key holders see published only.
          def scope
            base = Spree::Post.where(store: current_store)
            @secret_key_authenticated ? base : base.published
          end

          # ------------------------------------------------------------------ #
          # Model / serializer                                                   #
          # ------------------------------------------------------------------ #

          def model_class
            Spree::Post
          end

          def serializer_class
            Spree::Api::V3::PostSerializer
          end

          # ------------------------------------------------------------------ #
          # Resource helpers                                                     #
          # ------------------------------------------------------------------ #

          # Resolve by prefixed ID (post_xxx) or friendly slug.
          def find_resource
            id = params[:id]
            if id.to_s.start_with?('post_')
              scope.find_by_prefix_id!(id)
            else
              scope.friendly.find(id)
            end
          end

          def build_resource
            Spree::Post.new(permitted_params).tap do |post|
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

          # ------------------------------------------------------------------ #
          # Private helpers                                                      #
          # ------------------------------------------------------------------ #

          private

          def write_action?
            action_name.to_sym.in?(%i[create update destroy])
          end

          def extract_api_key
            request.headers['X-Spree-Api-Key'].presence || params[:api_key]
          end
        end
      end
    end
  end
end
