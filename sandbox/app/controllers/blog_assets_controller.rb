# BlogAssetsController — accepts multipart file uploads and returns an
# ActiveStorage signed_id that can be passed to Spree::Post#image.
#
# POST /blog_assets
#   Headers: X-Spree-Api-Key: <store api key>  (same key used for /api/v3/store/*)
#   Body:    multipart/form-data, field name "file"
#   Returns: { "signed_id": "eyJfcmFpbHMi..." }
#
# Auth: uses the store's publishable OR secret API key (same as Spree API v3).
# CSRF is skipped because this is an API endpoint (no browser session).
class BlogAssetsController < ActionController::API
  include Spree::Api::V3::ApiKeyAuthentication
  include Spree::Core::ControllerHelpers::Store

  before_action :authenticate_any_api_key!

  # POST /blog_assets
  def create
    unless params[:file].present?
      return render json: { error: 'Missing file parameter' }, status: :unprocessable_entity
    end

    upload = params[:file]

    # Support both ActionDispatch::Http::UploadedFile and plain string paths
    unless upload.respond_to?(:read)
      return render json: { error: 'file must be a multipart upload' }, status: :unprocessable_entity
    end

    filename  = params[:filename].presence || upload.original_filename.presence || 'upload'
    mime_type = upload.content_type.presence ||
                Marcel::MimeType.for(upload, name: filename) ||
                'application/octet-stream'

    blob = ActiveStorage::Blob.create_and_upload!(
      io:           upload,
      filename:     filename,
      content_type: mime_type
    )

    render json: { signed_id: blob.signed_id }, status: :created
  rescue ActiveStorage::IntegrityError => e
    render json: { error: "File integrity check failed: #{e.message}" }, status: :unprocessable_entity
  rescue StandardError => e
    Rails.logger.error "[BlogAssetsController] Upload failed: #{e.class}: #{e.message}\n#{e.backtrace.first(5).join("\n")}"
    render json: { error: 'Upload failed', detail: e.message }, status: :internal_server_error
  end

  private

  # Accepts either a publishable or secret store API key.
  def authenticate_any_api_key!
    key_token = extract_api_key
    return render_unauthorized if key_token.blank?

    store = current_store
    @current_api_key = store.api_keys.active.find_by(token: key_token)
    return render_unauthorized unless @current_api_key

    Spree::ApiKeyTouchJob.perform_later(@current_api_key.id)
  end

  def extract_api_key
    request.headers['X-Spree-Api-Key'].presence ||
      request.headers['X-Spree-API-Key'].presence ||
      params[:api_key]
  end

  def render_unauthorized
    render json: { error: 'Valid API key required' }, status: :unauthorized
  end
end
