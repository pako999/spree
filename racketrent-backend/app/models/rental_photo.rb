class RentalPhoto < ApplicationRecord
  belongs_to :rental
  has_one_attached :image

  validates :photo_type, presence: true, inclusion: { in: %w[front back side] }
end
