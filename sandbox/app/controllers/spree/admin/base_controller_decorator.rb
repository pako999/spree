module Spree
  module Admin
    module BaseControllerDecorator
      def self.prepended(base)
        # Skip the strict storefront security headers for all admin controllers
        base.skip_before_action :set_security_headers, raise: false

        base.content_security_policy do |policy|
          # Relax frame-ancestors to :self for admin previews
          policy.frame_ancestors :self
          # Allow some scripts/styles to be unsafe-inline in admin if needed by builder
          policy.script_src :self, :https, :unsafe_inline, 'https://unpkg.com', 'https://cdn.jsdelivr.net'
        end

        base.after_action :relax_admin_security_headers
      end

      private

      def relax_admin_security_headers
        # Explicitly ensure these headers are relaxed for the theme builder
        response.headers['Cross-Origin-Opener-Policy'] = 'unsafe-none'
        response.headers['Referrer-Policy'] = 'no-referrer-when-downgrade'
      end
    end
  end
end

if defined?(Spree::Admin::BaseController)
  Spree::Admin::BaseController.prepend Spree::Admin::BaseControllerDecorator
end
