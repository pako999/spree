# frozen_string_literal: true

# Subscribes to order.completed events and creates a Naročilo kupca
# (Sales Order) in the e-Računi invoicing system.
#
# The actual API call happens in CreateEracuniOrderJob (async via SolidQueue)
# so it doesn't block the checkout flow.
module Spree
  class EracuniOrderSubscriber < Spree::Subscriber
    subscribes_to 'order.completed'

    on 'order.completed', :create_sales_order

    private

    def create_sales_order(event)
      order_id = event.payload['id']
      return unless order_id

      # Skip if e-Računi is not configured (avoid noisy errors in dev/test)
      unless ENV["ERACUNI_API_USERNAME"].present?
        Rails.logger.debug "[EracuniOrderSubscriber] e-Računi not configured, skipping."
        return
      end

      CreateEracuniOrderJob.perform_later(order_id)
    rescue => e
      Rails.error.report(e, context: { subscriber: "EracuniOrderSubscriber", order_id: order_id }, handled: true)
    end
  end
end
