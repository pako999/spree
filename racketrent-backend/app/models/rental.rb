class Rental < ApplicationRecord
  belongs_to :racket
  belongs_to :customer
  belongs_to :admin_user, optional: true
  has_many :rental_photos, dependent: :destroy

  validates :status, inclusion: { in: %w[active overdue returned cancelled] }
  validates :price_per_day_cents, :total_price_cents, :rental_days, presence: true
  validates :starts_at, :due_at, presence: true

  scope :active_rentals, -> { where(status: 'active') }
  scope :overdue, -> { where(status: 'active').where('due_at < ?', Time.current) }
  scope :due_today, -> { where(status: 'active').where(due_at: Time.current.beginning_of_day..Time.current.end_of_day) }

  before_validation :calculate_total, on: :create

  def overdue?
    status == 'active' && due_at < Time.current
  end

  def return!
    transaction do
      update!(status: 'returned', returned_at: Time.current)
      racket.mark_available!
    end
  end

  def extend!(extra_days)
    transaction do
      ext_price = extra_days * price_per_day_cents
      update!(
        due_at: due_at + extra_days.days,
        extension_days: extension_days + extra_days,
        extension_price_cents: extension_price_cents + ext_price,
        total_price_cents: total_price_cents + ext_price
      )
    end
  end

  private

  def calculate_total
    self.total_price_cents = (price_per_day_cents || 0) * (rental_days || 1)
  end
end
