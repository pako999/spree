class Spree::AdminUser < Spree.base_class
    # Spree modules
    include Spree::UserMethods
  # :registerable intentionally omitted — admin accounts are created only via the admin panel.
  # A public /admin_users/sign_up endpoint would be a critical security risk.
  devise :database_authenticatable, :recoverable, :rememberable, :validatable
end
