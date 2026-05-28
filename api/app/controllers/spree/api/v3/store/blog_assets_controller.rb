# frozen_string_literal: true

module Spree
  module Api
    module V3
      module Store
        # Dedicated endpoint for uploading blog images before creating a post.
        # Upload returns the blob signed_id which can then be passed as
        # post[image] when creating/updating a post.
        #
        # POST /api/v3/store/blog_assets
        # Auth: secret key required
        # Params: file (multipart)
        # Response: { signed_id, url, filename, content_type, byte_size }
        class BlogAssetsController < ResourceController
          # Image upload is a write operation — require secret key, not publishable.
          skip_before_action :authenticate_api_key!, raise: false
          before_action :authenticate_secret_key!

          def create
            file = params.require(:file)

            blob = ActiveStorage::Blob.create_and_upload!(
              io:           file.tempfile,
              filename:     file.original_filename,
              content_type: file.content_type
            )

            render json: {
              signed_id:    blob.signed_id,
              url:          rails_blob_url(blob, host: request.base_url),
              filename:     blob.filename.to_s,
              content_type: blob.content_type,
              byte_size:    blob.byte_size
            }, status: :created
          end
        end
      end
    end
  end
end
