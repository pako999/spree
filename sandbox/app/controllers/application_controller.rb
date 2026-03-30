class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  before_action :set_security_headers

  private

  def set_security_headers
    # Strict storefront security headers
    response.headers['X-Content-Type-Options']    = 'nosniff'
    response.headers['X-XSS-Protection']          = '0'
    response.headers['Referrer-Policy']            = 'strict-origin-when-cross-origin'
    response.headers['Permissions-Policy']         = 'camera=(), microphone=(), geolocation=(), payment=(self)'
    response.headers['Cross-Origin-Opener-Policy'] = 'same-origin-allow-popups'
  end
end
