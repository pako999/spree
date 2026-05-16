class Racket < ApplicationRecord
  belongs_to :racket_type
  has_many :rentals, dependent: :restrict_with_error

  validates :qr_code, presence: true, uniqueness: true
  validates :status, inclusion: { in: %w[available rented maintenance retired] }

  scope :available, -> { where(status: 'available') }

  before_validation :generate_qr_code, on: :create

  def available?
    status == 'available'
  end

  def mark_rented!
    update!(status: 'rented')
  end

  def mark_available!
    update!(status: 'available')
  end

  private

  def generate_qr_code
    self.qr_code ||= "RR-#{SecureRandom.hex(6).upcase}"
  end
end
