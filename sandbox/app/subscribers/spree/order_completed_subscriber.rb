# Order completed subscriber.
# - Telegram: shop owner notification (kept — instant push to phone)
# - Customer order confirmation: Klaviyo flow on "Placed Order" event
# - Newsletter signup: Klaviyo subscribe if accept_marketing checked
# All email sending goes through Klaviyo — no SMTP needed.
module Spree
  class OrderCompletedSubscriber < Spree::Subscriber
    subscribes_to 'order.completed'

    def handle(event)
      oid = event.payload['id']
      order = Spree::Order.find_by(prefix_id: oid) || Spree::Order.find_by(id: oid)

      unless order
        Rails.logger.warn "[OrderCompletedSubscriber] Order #{oid} not found."
        return
      end

      # Telegram notification to shop owner
      Spree::TelegramNotifier.send_order_notification(order)

      # Auto-subscribe to Klaviyo newsletter if customer ticked "accept marketing"
      if order.respond_to?(:accept_marketing?) && order.accept_marketing? && order.email.present?
        klaviyo = order.store&.integrations&.active&.find_by(type: 'Spree::Integrations::Klaviyo')
        klaviyo&.subscribe_user(order.email)
      end

      # Order confirmation email is sent by Klaviyo flow on "Placed Order" event
      # (event already fired by spree_klaviyo gem's order_decorator).
      # Mark as delivered so the broken vendor OrderEmailSubscriber skips it.
      order.update_column(:confirmation_delivered, true) unless order.confirmation_delivered?
      order.update_column(:store_owner_notification_delivered, true) unless order.store_owner_notification_delivered?
    rescue StandardError => e
      Rails.error.report(e, message: "[OrderCompletedSubscriber] Error: #{e.message}", handled: true)
    end
  end
end
