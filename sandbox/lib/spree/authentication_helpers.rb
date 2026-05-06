module Spree
  module AuthenticationHelpers
    def self.included(receiver)
      receiver.helper_method(
        :spree_current_user,
        :spree_login_path,
        :spree_signup_path,
        :spree_logout_path,
        :spree_forgot_password_path,
        :spree_edit_password_path,
        :spree_admin_login_path,
        :spree_admin_logout_path
      )
    end

    def spree_current_user
      send("current_#{Spree.user_class.model_name.singular_route_key}")
    end

    # Use direct Rails route helpers to avoid Devise URL proxy issues
    # when called from within the Spree engine view/controller context.
    def spree_login_path(opts = {})
      Rails.application.routes.url_helpers.new_user_session_path(opts)
    end

    def spree_signup_path(opts = {})
      Rails.application.routes.url_helpers.new_user_registration_path(opts)
    end

    def spree_logout_path(opts = {})
      Rails.application.routes.url_helpers.destroy_user_session_path(opts)
    end

    def spree_forgot_password_path(opts = {})
      Rails.application.routes.url_helpers.new_user_password_path(opts)
    end

    def spree_edit_password_path(opts = {})
      Rails.application.routes.url_helpers.edit_user_registration_path(opts)
    end

    def spree_admin_login_path(opts = {})
      Rails.application.routes.url_helpers.new_admin_user_session_path(opts)
    end

    def spree_admin_logout_path(opts = {})
      Rails.application.routes.url_helpers.destroy_admin_user_session_path(opts)
    end
  end
end

ApplicationController.include Spree::AuthenticationHelpers if defined?(ApplicationController)
