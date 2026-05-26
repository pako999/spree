# frozen_string_literal: true

# Serves the account pane content inside the turbo-frame id="login".
# Always returns the right content based on auth state — so the pane
# doesn't need to rely on spree_current_user being available in the layout.
class AccountPaneController < ApplicationController
  def show
    # Renders app/views/account_pane/show.html.erb
  end
end
