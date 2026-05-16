class Customer < ApplicationRecord
  has_many :rentals, dependent: :restrict_with_error

  validates :first_name, :last_name, :email, presence: true
  validates :preferred_language, inclusion: { in: %w[en de sl hr it fr es] }

  scope :search, ->(q) {
    where('first_name LIKE :q OR last_name LIKE :q OR email LIKE :q OR phone LIKE :q', q: "%#{q}%")
  }

  def full_name
    "#{first_name} #{last_name}"
  end
end
