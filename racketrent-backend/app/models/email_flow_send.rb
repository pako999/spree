class EmailFlowSend < ApplicationRecord
  belongs_to :email_flow
  belongs_to :stringing_customer
  belongs_to :stringing_order, optional: true

  validates :status, inclusion: { in: %w[pending sent failed opened] }

  before_create :generate_tracking_token

  scope :recent, -> { order(created_at: :desc) }

  def mark_sent!
    update!(status: 'sent', sent_at: Time.current)
  end

  def mark_opened!
    update!(status: 'opened', opened_at: Time.current) unless opened_at.present?
  end

  def mark_failed!
    update!(status: 'failed')
  end

  private

  def generate_tracking_token
    self.tracking_token = SecureRandom.urlsafe_base64(32)
  end
end
