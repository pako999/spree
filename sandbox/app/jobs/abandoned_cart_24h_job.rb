# frozen_string_literal: true
#
# Sends a second cart-abandonment email with a discount offer to customers
# who received the first email but still haven't completed their order.
#
# Targeting window: orders last updated ~24 hours ago, still in incomplete state.
#
# Deduplication: Rails.cache (SolidCache) holds a key for each order that was
# already sent a 24h email; expiry is 7 days.
#
# Scheduled: every hour at :45 past (see config/recurring.yml)
class AbandonedCart24hJob < ApplicationJob
  queue_as :background

  INCOMPLETE_STATES = %w[cart address delivery payment].freeze
  ABANDON_WINDOW = (23.5.hours..24.5.hours)

  def perform
    cutoff_min = ABANDON_WINDOW.min.ago
    cutoff_max = ABANDON_WINDOW.max.ago

    candidates = Spree::Order
      .where(state: INCOMPLETE_STATES)
      .where.not(email: [nil, ''])
      .where(updated_at: cutoff_max..cutoff_min)

    Rails.logger.info "[AbandonedCart24hJob] #{candidates.count} candidate orders in window #{cutoff_max}..#{cutoff_min}"

    candidates.each do |order|
      next if already_emailed?(order)
      next if order.line_items.empty?

      AbandonedCartMailer.abandoned_cart_24h(order.id).deliver_later
      mark_emailed(order)
      Rails.logger.info "[AbandonedCart24hJob] queued 24h email for order #{order.number} (#{order.email})"
    end
  end

  private

  def cache_key(order)
    "abandoned_cart_24h_emailed/#{order.id}/#{order.number}"
  end

  def already_emailed?(order)
    Rails.cache.exist?(cache_key(order))
  end

  def mark_emailed(order)
    Rails.cache.write(cache_key(order), true, expires_in: 7.days)
  end
end
