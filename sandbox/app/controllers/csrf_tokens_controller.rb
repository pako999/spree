# frozen_string_literal: true

# Lightweight endpoint that returns a fresh CSRF token and establishes a session.
# Called by JavaScript when the page was served from Cloudflare cache (no session
# cookie present), so that subsequent form submissions / Turbo requests succeed.
class CsrfTokensController < ApplicationController
  def show
    response.set_header('Cache-Control', 'no-store, no-cache, private')
    render json: { token: form_authenticity_token }
  end
end
