# frozen_string_literal: true
#
# Sends a single cart-abandonment email to customers who started checkout
# but never completed it.
#
# Targeting window: orders last updated 60–90 minutes ago with an email address
# that are still in an incomplete checkout state.
#
# Deduplication: Rails.cache (SolidCache in production) holds a key for each
# order that was already emailed; expiry is 7 days so we never spam twice.
#
# Scheduled: every hour at :30 past (see config/recurring.yml)
class AbandonedCartJob < ApplicationJob
  queue_as :background

  # States that mean the customer started but never finished checkout
  INCOMPLETE_STATES = %w[cart address delivery payment].freeze

  # How long ago the order must have been last touched to qualify
  ABANDON_WINDOW = (95.minutes..125.minutes)

  def perform
    cutoff_min = ABANDON_WINDOW.min.ago
    cutoff_max = ABANDON_WINDOW.max.ago

    candidates = Spree::Order
      .where(state: INCOMPLETE_STATES)
      .where.not(email: [nil, ''])
      .where(updated_at: cutoff_max..cutoff_min)

    Rails.logger.info "[AbandonedCartJob] #{candidates.count} candidate orders in window #{cutoff_max}..#{cutoff_min}"

    candidates.each do |order|
      next if already_emailed?(order)
      next if order.line_items.empty?

      AbandonedCartMailer.abandoned_cart(order.id).deliver_later
      mark_emailed(order)
      Rails.logger.info "[AbandonedCartJob] queued email for order #{order.number} (#{order.email})"
    end
  end

  private

  def cache_key(order)
    "abandoned_cart_emailed/#{order.id}/#{order.number}"
  end

  def already_emailed?(order)
    Rails.cache.exist?(cache_key(order))
  end

  def mark_emailed(order)
    Rails.cache.write(cache_key(order), true, expires_in: 7.days)
  end
end
