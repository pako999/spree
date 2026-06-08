# frozen_string_literal: true

# Decorates Spree::Admin::OrdersController to add graceful error handling
# around the cancel action.
#
# Root cause: when an order has a *captured* Saferpay payment, calling
# `order.canceled_by(user)` triggers `payments.completed.each(&:cancel!)`
# which sends POST /Payment/v1/Transaction/Cancel to Saferpay. Saferpay
# returns VALIDATION_FAILED because you can only void an *authorized-but-
# not-yet-captured* transaction — captured payments need a Refund instead.
# Spree wraps this in Spree::Core::GatewayError and the stock controller
# has no rescue clause, so it bubbles up as a 500.
#
# Fix: catch GatewayError, cancel the order's state-machine and shipments
# *without* touching payments, then show the admin a clear flash explaining
# that a manual refund is required.

module Spree
  module Admin
    module OrdersControllerDecorator
      # PUT /admin/orders/:id/cancel
      def cancel
        @order.canceled_by(try_spree_current_user)
        flash[:success] = Spree.t(:order_canceled)
        redirect_back fallback_location: spree.edit_admin_order_url(@order)
      rescue Spree::Core::GatewayError => e
        handle_gateway_error_on_cancel(e)
      end

      private

      # Called when the payment gateway rejects the void because the payment
      # is already captured. We still cancel the order + shipments via direct
      # column updates (bypassing state-machine callbacks that would try to
      # void payments a second time), and tell the admin a manual refund
      # may still be needed.
      def handle_gateway_error_on_cancel(error)
        Rails.logger.warn "[OrdersControllerDecorator] GatewayError on cancel " \
                          "for #{@order&.number}: #{error.message}"

        cancelled_ok = false

        begin
          @order.transaction do
            @order.update_columns(
              state: 'canceled',
              canceler_id: try_spree_current_user&.id,
              canceled_at: Time.current,
              updated_at: Time.current
            )

            @order.shipments.each do |shipment|
              next if shipment.state == 'shipped' || shipment.state == 'canceled'
              shipment.update_columns(state: 'canceled', updated_at: Time.current)
            rescue => se
              Rails.logger.warn "[OrdersControllerDecorator] Could not cancel shipment #{shipment.number}: #{se.message}"
            end
          end
          cancelled_ok = true
        rescue => cancel_error
          Rails.logger.error "[OrdersControllerDecorator] Force-cancel failed for " \
                             "#{@order&.number}: #{cancel_error.message}"
        end

        if cancelled_ok
          flash[:warning] = "Order #{@order.number} has been cancelled. " \
            "⚠️ The Saferpay payment could not be voided automatically " \
            "because it has already been captured. " \
            "If you have not already refunded the customer, please issue a manual refund from the Payments tab."
        else
          flash[:error] = "Could not cancel the order. " \
            "Saferpay error: #{error.message}. " \
            "The payment has already been captured — please issue a manual " \
            "refund first, then try cancelling again."
        end

        redirect_back fallback_location: spree.edit_admin_order_url(@order)
      end
    end
  end
end

Spree::Admin::OrdersController.prepend(Spree::Admin::OrdersControllerDecorator)
