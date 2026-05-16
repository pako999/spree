class StringingOrder < ApplicationRecord
  belongs_to :stringing_customer
  belongs_to :admin_user, optional: true

  validates :racket_brand, presence: true
  validates :price_cents, presence: true, numericality: { greater_than: 0 }
  validates :status, inclusion: { in: %w[received in_progress ready_for_pickup picked_up cancelled] }

  scope :by_status, ->(s) { where(status: s) if s.present? }
  scope :ready_count, -> { where(status: 'ready_for_pickup').count }

  before_validation :set_received_at, on: :create

  def start!
    update!(status: 'in_progress', started_at: Time.current)
  end

  def complete!
    update!(status: 'ready_for_pickup', completed_at: Time.current)
    StringingMailer.ready_for_pickup(self).deliver_later
  end

  def pickup!
    update!(status: 'picked_up', picked_up_at: Time.current)
  end

  def cancel!
    update!(status: 'cancelled')
  end

  def price
    price_cents / 100.0
  end

  private

  def set_received_at
    self.received_at ||= Time.current
  end
end
