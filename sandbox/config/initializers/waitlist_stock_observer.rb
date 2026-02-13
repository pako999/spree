# config/initializers/waitlist_stock_observer.rb
#
# Observes Spree::StockItem changes. When stock goes from 0 to > 0,
# enqueues NotifyWaitlistJob to email all waitlisted customers.

Rails.application.config.to_prepare do
  Spree::StockItem.class_eval do
    after_save :check_waitlist_for_restock

    private

    def check_waitlist_for_restock
      # Only trigger when count_on_hand changes
      return unless saved_change_to_count_on_hand?

      old_count = count_on_hand_before_last_save || 0
      new_count = count_on_hand

      # Trigger when item was out of stock (0 or less) and now has stock
      if old_count <= 0 && new_count > 0
        variant_id = self.variant_id
        pending_count = WaitlistEntry.pending.where(variant_id: variant_id).count

        if pending_count > 0
          Rails.logger.info "[Waitlist] Stock replenished for variant ##{variant_id}: #{old_count} → #{new_count}. #{pending_count} subscribers waiting."
          NotifyWaitlistJob.perform_later(variant_id)
        end
      end
    end
  end
end
