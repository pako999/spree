class NotifyWaitlistJob < ApplicationJob
  queue_as :default

  def perform(variant_id)
    variant = Spree::Variant.find_by(id: variant_id)
    return unless variant && variant.product

    # Find pending entries for this variant
    pending_entries = WaitlistEntry.pending.where(variant: variant)

    return if pending_entries.empty?

    # Deliver emails
    pending_entries.find_each do |entry|
      WaitlistMailer.restock_email(entry.id).deliver_later
    end

    # Mark all processed entries as notified
    # Doing this in bulk to avoid multiple row queries
    pending_entries.update_all(notified_at: Time.current)
    
    Rails.logger.info "[WaitlistJob] Sent #{pending_entries.count} restock emails for variant #{variant_id}"
  end
end
