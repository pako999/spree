# frozen_string_literal: true

# Subscribes to Spree order events and automatically pushes new orders
# to DHL Express Commerce (Starshipit) for label printing.
#
# Triggered on TWO events (same logic as EracuniOrderSubscriber):
#   1. order.completed — card/Saferpay orders paid immediately at checkout
#   2. order.paid      — bank transfer orders paid later (manual confirmation)
#
# PushOrderToDhlJob is idempotent: if a real DHL order ID already exists in
# private_metadata, it skips the API call — safe to fire on both events.
#
# Default package dimensions are used for auto-push; the admin can always
# manually re-push with custom dimensions from the order panel.
#
module Spree
  class DhlOrderSubscriber < Spree::Subscriber
    subscribes_to 'order.completed'
    subscribes_to 'order.paid'

    on 'order.completed', :push_to_dhl
    on 'order.paid',      :push_to_dhl

    private

    def push_to_dhl(event)
      order_id = event.payload['id']
      return unless order_id

      # Skip if DHL is not configured
      unless ENV['DHL_API_KEY'].present?
        Rails.logger.debug '[DhlOrderSubscriber] DHL not configured, skipping.'
        return
      end

      # Enqueue with default dimensions — admin can re-push with custom values
      PushOrderToDhlJob.perform_later(order_id)
      Rails.logger.info "[DhlOrderSubscriber] Enqueued PushOrderToDhlJob for order #{order_id}"
    rescue => e
      Rails.error.report(e, context: { subscriber: 'DhlOrderSubscriber', order_id: order_id }, handled: true)
    end
  end
end
