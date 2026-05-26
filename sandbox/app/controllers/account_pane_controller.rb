# frozen_string_literal: true

# Serves the account pane content inside the turbo-frame id="login".
# Always returns the right content based on auth state — so the pane
# doesn't need to rely on spree_current_user being available in the layout.
class AccountPaneController < ApplicationController
  def show
    # Never let Cloudflare or any CDN cache this — it's auth-sensitive
    response.headers['Cache-Control'] = 'no-store, private'
    response.headers['Vary'] = 'Cookie'
    # Renders app/views/account_pane/show.html.erb
  end
end
