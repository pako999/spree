# Order completed subscriber.
# - Telegram: shop owner notification (kept — instant push to phone)
# - Customer order confirmation: sent by Spree's OrderEmailSubscriber (native email)
# - Newsletter signup: Klaviyo subscribe if accept_marketing checked
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

      # Do NOT mark confirmation_delivered — Spree's OrderEmailSubscriber will send
      # the native order confirmation email to the customer.
      # Mark store_owner_notification_delivered to avoid duplicate shop owner email
      # (Telegram already handles that notification).
      order.update_column(:store_owner_notification_delivered, true) unless order.store_owner_notification_delivered?
    rescue StandardError => e
      Rails.error.report(e, handled: true, context: { subscriber: 'OrderCompletedSubscriber', order_id: oid })
    end
  end
end
