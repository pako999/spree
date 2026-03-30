# Be sure to restart your server when you modify this file.
# Content Security Policy — https://guides.rubyonrails.org/security.html#content-security-policy-header

Rails.application.configure do
  config.content_security_policy do |policy|
    # Trusted script sources: self + common Spree/Hotwire CDN origins
    policy.script_src  :self, :https,
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

    # XHR/fetch/WebSockets: self + Saferpay + Gemini API
    policy.connect_src :self,
                        'https://www.saferpay.com',
                        'https://test.saferpay.com',
                        'https://generativelanguage.googleapis.com'

    # Frame ancestors: allows same-origin embedding (required for theme builder)
    policy.frame_ancestors :self

    # No base tag hijacking
    policy.base_uri    :self

    # Form submissions only to self and Saferpay (external checkout redirect)
    policy.form_action :self, 'https://www.saferpay.com', 'https://test.saferpay.com'

    # Default: self for anything unspecified
    policy.default_src :self
  end

  # Generate session nonces for permitted inline scripts (importmap, Turbo)
  config.content_security_policy_nonce_generator = ->(_request) { SecureRandom.base64(16) }
  config.content_security_policy_nonce_directives = %w[script-src]

  # Automatically add nonce to javascript_tag, javascript_include_tag etc.
  config.content_security_policy_nonce_auto = true

  # Switch to report-only mode to test before enforcing:
  # config.content_security_policy_report_only = true
end
