# frozen_string_literal: true
module Spree
  class KlaviyoOrderSubscriber < Spree::Subscriber
    subscribes_to 'order.completed'

    on 'order.completed', :track_placed_order

    private

    def track_placed_order(event)
      order = Spree::Order.find_by(id: event.payload['id'])
      return unless order

      KlaviyoService.track_placed_order(order)
    rescue => e
      Rails.error.report(e, message: '[KlaviyoOrderSubscriber] track_placed_order failed', handled: true)
    end
  end
end
