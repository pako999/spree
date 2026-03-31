module Spree
  class OrderCompletedSubscriber < Spree::Subscriber
    subscribes_to 'order.completed'

    def handle(event)
      order_id = event.payload['id']
      order = Spree::Order.find_by(id: order_id)
      
      if order
        Spree::TelegramNotifier.send_order_notification(order)
      else
        Rails.logger.warn "[OrderCompletedSubscriber] Order ##{order_id} not found. Skipping Telegram notification."
      end
    rescue StandardError => e
      Rails.error.report(e, message: "[OrderCompletedSubscriber] Error handling order.complete event", handled: true)
    end
  end
end
