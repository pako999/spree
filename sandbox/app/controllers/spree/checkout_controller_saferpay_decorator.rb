# frozen_string_literal: true

# Override the checkout controller to handle Saferpay redirect-based payments.
# When a customer selects Saferpay as their payment method, instead of processing
# the payment inline, we initialize a Saferpay Payment Page and redirect them.

module Spree
  module CheckoutControllerSaferpayDecorator
    def self.prepended(base)
      base.class_eval do
        before_action :check_saferpay_redirect, only: :update
      end
    end

    private

    def check_saferpay_redirect
      return unless @order.state == 'payment'
      return unless params[:order] && params[:order][:payments_attributes]

      payment_attrs = params[:order][:payments_attributes]
      payment_method_id = payment_attrs.is_a?(Array) ? payment_attrs.first[:payment_method_id] : payment_attrs.values.first[:payment_method_id]
      return unless payment_method_id

      payment_method = Spree::PaymentMethod.find_by(id: payment_method_id)
      return unless payment_method.is_a?(Spree::Gateway::Saferpay)

      # Create the payment record
      @order.payments.where(state: ['checkout', 'pending']).map(&:invalidate!)

      begin
        # Build callback URLs
        base_url = request.base_url
        return_url = "#{base_url}/saferpay/success?order_number=#{@order.number}"
        fail_url = "#{base_url}/saferpay/fail?order_number=#{@order.number}"
        notify_url = "#{base_url}/saferpay/notify?order_number=#{@order.number}"

        # Initialize the Saferpay Payment Page
        result = payment_method.initialize_payment(
          order: @order,
          return_url: return_url,
          fail_url: fail_url,
          notify_url: notify_url
        )

        # Create a pending Spree payment with the Saferpay token
        payment = @order.payments.create!(
          payment_method: payment_method,
          amount: @order.total,
          state: 'checkout',
          transaction_id: result[:token] # Store Saferpay token for later Assert
        )

        Rails.logger.info("[Saferpay] Initialized payment for order #{@order.number}, redirecting to Saferpay")

        # Redirect to the Saferpay Payment Page
        redirect_to result[:redirect_url], allow_other_host: true
      rescue SaferpayError => e
        Rails.logger.error("[Saferpay] Initialize error: #{e.message}")
        flash[:error] = "Payment initialization failed: #{e.error_message}"
        redirect_to spree.checkout_state_path(@order.token, :payment)
      rescue StandardError => e
        Rails.logger.error("[Saferpay] Unexpected error: #{e.message}")
        flash[:error] = 'An error occurred while initializing payment. Please try again.'
        redirect_to spree.checkout_state_path(@order.token, :payment)
      end
    end
  end
end

Spree::CheckoutController.prepend(Spree::CheckoutControllerSaferpayDecorator)
