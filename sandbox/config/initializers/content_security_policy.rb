# Be sure to restart your server when you modify this file.
# Content Security Policy — https://guides.rubyonrails.org/security.html#content-security-policy-header

Rails.application.configure do
  config.content_security_policy do |policy|
    # Trusted script sources: self + common Spree/Hotwire CDN origins
    # unsafe_inline needed for page-section custom code blocks (stored in DB, cannot receive nonce)
    # blob: needed for ES module shims (importmap via module-shims.js creates blob: worker URLs)
    policy.script_src  :self, :https, :unsafe_inline, :blob,
                        'https://unpkg.com',
                        'https://cdn.jsdelivr.net'

    # Images: allow self, https, data URIs (for inline images and Active Storage)
    policy.img_src     :self, :https, :data, :blob

    # Styles: self + https (Spree admin uses inline styles extensively)
    policy.style_src   :self, :https, :unsafe_inline

    # Fonts from self or https CDNs
    policy.font_src    :self, :https, :data

    # Object/embed: none
    policy.object_src  :none

    # XHR/fetch/WebSockets: self + Saferpay + Gemini API + Cloudflare R2 (Active Storage direct upload)
    # wss: needed for ActionCable/Hotwire live updates in admin
    policy.connect_src :self,
                        'wss:',
                        'https://www.saferpay.com',
                        'https://test.saferpay.com',
                        'https://generativelanguage.googleapis.com',
                        'https://8b7e078431b06069d14ce4bd18839679.r2.cloudflarestorage.com'

    # Frames: allow YouTube embeds in product descriptions / TinyMCE
    policy.frame_src   :self,
                        'https://www.youtube.com',
                        'https://www.youtube-nocookie.com'

    # Frame ancestors: allows same-origin embedding (required for theme builder)
    policy.frame_ancestors :self

    # No base tag hijacking
    policy.base_uri    :self

    # Form submissions only to self and Saferpay (external checkout redirect)
    policy.form_action :self, 'https://www.saferpay.com', 'https://test.saferpay.com'

    # Default: self for anything unspecified
    policy.default_src :self
  end

  # Nonces disabled for script-src because page-section custom code blocks (stored in DB)
  # cannot receive a per-request nonce, and nonces take precedence over unsafe-inline in
  # CSP2+ browsers, which would prevent those scripts from executing.
  # config.content_security_policy_nonce_generator = ->(_request) { SecureRandom.base64(16) }
  # config.content_security_policy_nonce_directives = %w[script-src]
  # config.content_security_policy_nonce_auto = true

  # Switch to report-only mode to test before enforcing:
  # config.content_security_policy_report_only = true
end
