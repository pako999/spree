# Order completed subscriber.
# - Telegram: shop owner notification
# - Customer order confirmation: Spree::OrderMailer via Brevo SMTP
# - Store owner notification email: Spree::OrderMailer via Brevo SMTP
# (Klaviyo handles marketing flows — welcome, abandoned cart, winback — separately)
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

      # Customer order confirmation email
      unless order.confirmation_delivered?
        if order.store&.prefers_send_consumer_transactional_emails?
          Spree::OrderMailer.confirm_email(order.id).deliver_later
          order.update_column(:confirmation_delivered, true)
        end
      end

      # Store owner notification email
      if order.store&.new_order_notifications_email.present? && !order.store_owner_notification_delivered?
        Spree::OrderMailer.store_owner_notification_email(order.id).deliver_later
        order.update_column(:store_owner_notification_delivered, true)
      end
    rescue StandardError => e
      Rails.error.report(e, message: "[OrderCompletedSubscriber] Error: #{e.message}", handled: true)
    end
  end
end
