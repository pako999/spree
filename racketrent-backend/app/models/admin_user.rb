class AdminUser < ApplicationRecord
  has_secure_password

  has_many :rentals
  has_many :stringing_orders

  validates :email, presence: true, uniqueness: true
  validates :name, presence: true
  validates :role, inclusion: { in: %w[admin staff] }
end
