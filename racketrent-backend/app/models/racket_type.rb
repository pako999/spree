class RacketType < ApplicationRecord
  has_many :rackets, dependent: :restrict_with_error

  validates :name, presence: true
  validates :category, presence: true, inclusion: { in: %w[tennis padel] }
  validates :price_per_day_cents, presence: true, numericality: { greater_than: 0 }

  scope :active, -> { where(active: true) }

  def price_per_day
    price_per_day_cents / 100.0
  end
end
