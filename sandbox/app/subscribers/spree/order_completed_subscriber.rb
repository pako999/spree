# Order completed subscriber.
# - Sends Telegram notification to shop owner
# - Customer order confirmation emails: handled by Klaviyo flow
#   (triggered by "Placed Order" event sent via spree_klaviyo gem)
# - Shop owner notification: covered by Telegram (above)
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

      Spree::TelegramNotifier.send_order_notification(order)
    rescue StandardError => e
      Rails.error.report(e, message: "[OrderCompletedSubscriber] Error: #{e.message}", handled: true)
    end
  end
end
