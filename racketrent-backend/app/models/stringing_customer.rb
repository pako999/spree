class StringingCustomer < ApplicationRecord
  has_many :stringing_orders, dependent: :restrict_with_error
  has_many :email_flow_sends, dependent: :destroy

  validates :first_name, :last_name, :email, presence: true
  validates :preferred_language, inclusion: { in: %w[en de sl hr it fr es] }

  before_create :generate_unsubscribe_token

  scope :search, ->(q) {
    where('first_name LIKE :q OR last_name LIKE :q OR email LIKE :q OR phone LIKE :q', q: "%#{q}%")
  }
  scope :subscribed, -> { where(marketing_opt_in: true) }
  scope :inactive_for, ->(days) {
    subscribed.where.not(
      id: StringingOrder.where('picked_up_at > ?', days.days.ago).select(:stringing_customer_id)
    )
  }

  def full_name
    "#{first_name} #{last_name}"
  end

  def last_stringing_order
    stringing_orders.where(status: 'picked_up').order(picked_up_at: :desc).first
  end

  def days_since_last_stringing
    last = last_stringing_order
    return nil unless last&.picked_up_at
    (Date.current - last.picked_up_at.to_date).to_i
  end

  def unsubscribe!
    update!(marketing_opt_in: false)
  end

  private

  def generate_unsubscribe_token
    self.unsubscribe_token = SecureRandom.urlsafe_base64(32)
  end
end
