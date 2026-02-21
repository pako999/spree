class WaitlistEntry < ApplicationRecord
  belongs_to :variant, class_name: 'Spree::Variant'

  # A user shouldn't be able to sign up for the exact same variant multiple times 
  # unless their previous pending request has been notified (fulfilled).
  validates :email, uniqueness: { scope: :variant_id, message: "is already on the waitlist for this item", conditions: -> { where(notified_at: nil) } }

  # Scopes
  scope :pending, -> { where(notified_at: nil) }
end
