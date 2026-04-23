# v2 - prefix_id fix + email sending
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

      # Telegram notification
      Spree::TelegramNotifier.send_order_notification(order)

      # Order confirmation email (bypasses broken vendor OrderEmailSubscriber)
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
