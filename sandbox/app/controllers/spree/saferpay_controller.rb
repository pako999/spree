# frozen_string_literal: true

module Spree
  class SaferpayController < Spree::StoreController
    protect_from_forgery except: :notify

    # GET /saferpay/success?order_number=X
    def success
      order = find_order
      return redirect_to_cart('Order not found') unless order

      payment = order.payments.where(
        payment_method_type: 'Spree::Gateway::Saferpay',
        state: ['checkout', 'pending', 'processing']
      ).last

      return redirect_to_cart('Payment not found') unless payment

      saferpay_token = payment.transaction_id
      return redirect_to_cart('Saferpay token not found') unless saferpay_token

      begin
        gateway = payment.payment_method

        # Step 1: Assert the payment
        assert_response = gateway.assert_payment(token: saferpay_token)
        transaction = assert_response['Transaction']
        transaction_id = transaction['Id']
        transaction_status = transaction['Status']

        Rails.logger.info("[Saferpay] Assert success: Transaction #{transaction_id}, Status: #{transaction_status}")

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
            payment.started_processing! if payment.can_started_processing?
            payment.complete! if payment.can_complete?
            payment.capture_events.create!(amount: order.total)
            Rails.logger.info("[Saferpay] Capture success for order #{order.number}")
          else
            Rails.logger.error("[Saferpay] Capture failed: #{capture_response.message}")
            payment.failure! if payment.can_failure?
            return redirect_to_checkout(order, 'Payment capture failed. Please try again.')
          end
        elsif transaction_status == 'CAPTURED'
          payment.started_processing! if payment.can_started_processing?
          payment.complete! if payment.can_complete?
          payment.capture_events.create!(amount: order.total)
          Rails.logger.info("[Saferpay] Already captured for order #{order.number}")
        end

        # Complete the order
        if order.can_complete?
          order.complete!
        elsif order.state != 'complete'
          until order.state == 'complete' || !order.can_next?
            order.next!
          end
        end

        store_payment_info(payment, assert_response)

        flash[:success] = 'Payment successful! Your order has been placed.'
        redirect_to spree.order_path(order)

      rescue SaferpayError => e
        Rails.logger.error("[Saferpay] Assert/Capture error: #{e.message}")
        payment.failure! if payment.can_failure?
        redirect_to_checkout(order, "Payment verification failed: #{e.error_message}")
      rescue StandardError => e
        Rails.logger.error("[Saferpay] Unexpected error: #{e.message}\n#{e.backtrace&.first(5)&.join("\n")}")
        payment.failure! if payment&.can_failure?
        redirect_to_checkout(order, 'An unexpected error occurred. Please try again.')
      end
    end

    # GET /saferpay/fail?order_number=X
    def fail
      order = find_order
      if order
        payment = order.payments.where(
          payment_method_type: 'Spree::Gateway::Saferpay'
        ).last
        payment&.failure! if payment&.can_failure?
        redirect_to_checkout(order, 'Payment was cancelled or failed. Please try again.')
      else
        redirect_to_cart('Order not found')
      end
    end

    # POST /saferpay/notify
    def notify
      order = find_order
      return head :not_found unless order

      payment = order.payments.where(
        payment_method_type: 'Spree::Gateway::Saferpay',
        state: ['checkout', 'pending', 'processing']
      ).last
      return head :not_found unless payment

      begin
        gateway = payment.payment_method
        saferpay_token = payment.transaction_id

        assert_response = gateway.assert_payment(token: saferpay_token)
        transaction = assert_response['Transaction']
        transaction_id = transaction['Id']

        payment.update!(
          response_code: transaction_id,
          transaction_id: transaction_id
        )

        if transaction['Status'] == 'AUTHORIZED'
          capture_response = gateway.capture(
            (order.total * 100).to_i,
            transaction_id
          )

          if capture_response.success?
            payment.started_processing! if payment.can_started_processing?
            payment.complete! if payment.can_complete?
            payment.capture_events.create!(amount: order.total)
          end
        elsif transaction['Status'] == 'CAPTURED'
          payment.started_processing! if payment.can_started_processing?
          payment.complete! if payment.can_complete?
          payment.capture_events.create!(amount: order.total)
        end

        order.complete! if order.can_complete?
        head :ok
      rescue StandardError => e
        Rails.logger.error("[Saferpay] Notify error: #{e.message}")
        head :internal_server_error
      end
    end

    private

    def find_order
      order_number = params[:order_number]
      return nil unless order_number
      Spree::Order.find_by(number: order_number)
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
