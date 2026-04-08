# frozen_string_literal: true

module Spree
  class SaferpayController < Spree::StoreController
    protect_from_forgery except: :notify

    # GET /saferpay/success?order_number=X
    def success
      order = find_order
      return redirect_to_cart('Order not found') unless order

      payment = find_saferpay_payment(order)
      return redirect_to_cart('Payment not found') unless payment

      # Already completed by notify webhook — just redirect
      if payment.completed?
        flash[:success] = Spree.t(:payment_success, scope: :saferpay, default: 'Payment successful! Your order has been placed.')
        return redirect_to spree.order_path(order)
      end

      saferpay_token = payment.transaction_id
      return redirect_to_cart('Saferpay token not found') unless saferpay_token

      begin
        process_saferpay_payment(order, payment, saferpay_token)

        flash[:success] = Spree.t(:payment_success, scope: :saferpay, default: 'Payment successful! Your order has been placed.')
        redirect_to spree.order_path(order)
      rescue SaferpayError => e
        Rails.logger.error("[Saferpay] Assert/Capture error for order #{order.number}: #{e.message}")
        payment.failure! if payment.can_failure?
        redirect_to_checkout(order, "Payment verification failed: #{e.error_message}")
      rescue StandardError => e
        Rails.logger.error("[Saferpay] Unexpected error for order #{order.number}: #{e.message}\n#{e.backtrace&.first(5)&.join("\n")}")
        payment.failure! if payment&.can_failure?
        redirect_to_checkout(order, 'An unexpected error occurred. Please try again.')
      end
    end

    # GET /saferpay/fail?order_number=X
    def fail
      order = find_order
      if order
        saferpay_method_ids = Spree::PaymentMethod.where(type: 'Spree::Gateway::Saferpay').pluck(:id)
        payment = order.payments.where(payment_method_id: saferpay_method_ids).last
        payment&.failure! if payment&.can_failure?
        redirect_to_checkout(order, 'Payment was cancelled or failed. Please try again.')
      else
        redirect_to_cart('Order not found')
      end
    end

    # POST /saferpay/notify — server-to-server callback
    def notify
      order = find_order
      return head :not_found unless order

      payment = find_saferpay_payment(order)
      return head :not_found unless payment

      # Already processed by success redirect
      return head :ok if payment.completed?

      saferpay_token = payment.transaction_id
      return head :unprocessable_entity unless saferpay_token

      begin
        process_saferpay_payment(order, payment, saferpay_token)
        head :ok
      rescue StandardError => e
        Rails.logger.error("[Saferpay] Notify error for order #{order.number}: #{e.message}")
        head :internal_server_error
      end
    end

    private

    def find_order
      order_number = params[:order_number]
      return nil unless order_number

      Spree::Order.find_by(number: order_number)
    end

    def find_saferpay_payment(order)
      saferpay_method_ids = Spree::PaymentMethod.where(type: 'Spree::Gateway::Saferpay').pluck(:id)
      order.payments.where(
        payment_method_id: saferpay_method_ids,
        state: %w[checkout pending processing]
      ).last
    end

    def process_saferpay_payment(order, payment, saferpay_token)
      order.with_lock do
        # Re-check inside lock to avoid race condition between success and notify
        payment.reload
        return if payment.completed?

        gateway = payment.payment_method

        # Step 1: Assert the payment
        assert_response = gateway.assert_payment(token: saferpay_token)
        transaction = assert_response['Transaction']
        transaction_id = transaction['Id']
        transaction_status = transaction['Status']

        Rails.logger.info("[Saferpay] Assert for order #{order.number}: Transaction #{transaction_id}, Status: #{transaction_status}")

        # Store the real Saferpay transaction ID (replacing the token)
        payment.update!(
          response_code: transaction_id,
          transaction_id: transaction_id
        )

        # Step 2: Capture if authorized
        if transaction_status == 'AUTHORIZED'
          capture_response = gateway.capture(
            (order.total * 100).to_i,
            transaction_id
          )

          if capture_response.success?
            capture_id = capture_response.authorization
            payment.update!(response_code: capture_id) if capture_id.present?
            complete_payment(payment, order)
            Rails.logger.info("[Saferpay] Capture success for order #{order.number}, CaptureId: #{capture_id}")
          else
            Rails.logger.error("[Saferpay] Capture failed for order #{order.number}: #{capture_response.message}")
            payment.failure! if payment.can_failure?
            raise StandardError, "Payment capture failed: #{capture_response.message}"
          end
        elsif transaction_status == 'CAPTURED'
          complete_payment(payment, order)
          Rails.logger.info("[Saferpay] Already captured for order #{order.number}")
        else
          Rails.logger.error("[Saferpay] Unexpected status for order #{order.number}: #{transaction_status}")
          payment.failure! if payment.can_failure?
          raise StandardError, "Unexpected payment status: #{transaction_status}"
        end

        store_payment_info(payment, assert_response)

        # Advance order to complete
        complete_order(order)
      end
    end

    def complete_payment(payment, order)
      payment.started_processing! if payment.checkout?
      payment.pend! if payment.processing?
      payment.complete! if payment.can_complete?
      payment.capture_events.create!(amount: order.total)
    end

    def complete_order(order)
      until order.state == 'complete' || !order.can_next?
        order.next!
      end
    end

    def redirect_to_cart(message)
      flash[:error] = message
      redirect_to spree.cart_path
    end

    def redirect_to_checkout(order, message)
      flash[:error] = message
      redirect_to spree.checkout_state_path(state: :payment)
    end

    def store_payment_info(payment, assert_response)
      payment_means = assert_response['PaymentMeans']
      return unless payment_means

      info = {}
      info[:brand] = payment_means.dig('Brand', 'Name')
      info[:payment_method] = payment_means.dig('Brand', 'PaymentMethod')
      info[:display_text] = payment_means['DisplayText']

      if payment_means['Card']
        info[:card_number] = payment_means.dig('Card', 'MaskedNumber')
        info[:card_holder] = payment_means.dig('Card', 'HolderName')
        info[:card_expiry] = "#{payment_means.dig('Card', 'ExpMonth')}/#{payment_means.dig('Card', 'ExpYear')}"
      end

      payment.log_entries.create!(details: info.to_yaml)
    rescue StandardError => e
      Rails.logger.warn("[Saferpay] Could not store payment info: #{e.message}")
    end
  end
end
