module Spree
  class UserSessionsController < ::Devise::SessionsController
    include Spree::Storefront::DeviseConcern

    # When the account pane header loads /users/sign_in via turbo frame,
    # the full storefront layout also contains an empty <turbo-frame id="login">
    # which Turbo grabs first (showing "Content missing"). Skip the layout so
    # only the view's turbo frame is returned for turbo frame requests.
    layout -> { request.headers['Turbo-Frame'].present? ? false : 'spree/storefront' }

    protected

    def translation_scope
      'devise.user_sessions'
    end

    private

    def title
      Spree.t(:login)
    end
  end
end
